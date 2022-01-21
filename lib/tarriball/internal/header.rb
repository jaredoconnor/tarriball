require 'stringio'
require_relative '../mode'

module Tarriball
  module Internal
    class Header
      attr_reader :ustar, :path, :size_data, :mode_data, :user_id_data, :group_id_data, :last_modified_data, :type_data, :link_path_data
  
      def initialize ustar:, path:, size_data:, mode_data:, user_id_data:, group_id_data:, last_modified_data:, type_data:, link_path_data:
        @ustar = ustar
        @path = path
        @size_data = size_data
        @mode_data = mode_data
        @user_id_data = user_id_data
        @group_id_data = group_id_data
        @last_modified_data = last_modified_data
        @type_data = type_data
        @link_path_data = link_path_data
      end

      def type
        @type_data == "\0" ? '0' : @type_data
      end
  
      def directory?
        if ustar
          type == '5'
        else
          type == '0' && @size_data == 0 && @path.end_with?('/')
        end
      end
  
      def file?
        type == '0'
      end
  
      def mode
        Mode.from_decimal @mode_data
      end

      def write_to_io io, path_prefix: nil
        raise 'Only writing UStar headers is supported.' unless @ustar
        raise "Tarball header contains a non-ASCII path: #{path}" unless @path.ascii_only?
        if path.split(File::SEPARATOR).any? { |segment| segment == '..' }
          raise "Tarball header path references a parent directory: #{path}"
        end
        if path_prefix && @path.start_with?(path_prefix)
          name = @path[path_prefix.length...]
          prefix = path_prefix
        else
          name = @path
          prefix = ''
        end
        if directory? && ! name.end_with?(File::SEPARATOR)
          name += File::SEPARATOR
        end
        raise 'Tarball header name missing.' unless name.length > 0
        raise 'Tarball header name must be shorter than 100 characters.' unless name.length < 100
        raise 'Tarball header prefix must be shorter than 155 characters.' unless prefix.length < 155
        last_modified = @last_modified_data
        if last_modified.to_s(8).length > 11
          last_modified = 0
        end
        blank_checksum = '        '
        ustar_indicator = 'ustar'
        ustar_version = '00'
        user_name = ''
        group_name = ''
        major_version = 0
        minor_version = 0

        output = ''
        fields = [
          { value: name, length: 100 },
          { value: @mode_data, length: 8 },
          { value: @user_id_data, length: 8 },
          { value: @group_id_data, length: 8 },
          { value: @size_data, length: 12 },
          { value: last_modified, length: 12 },
          { value: blank_checksum, length: 8 },
          { value: @type_data, length: 1 },
          { value: @link_path_data, length: 100 },
          { value: ustar_indicator, length: 6 },
          { value: ustar_version, length: 2 },
          { value: user_name, length: 32 },
          { value: group_name, length: 32 },
          { value: major_version, length: 8 },
          { value: minor_version, length: 8 },
          { value: prefix, length: 155 }
        ]
        fields.each do |field|
          value = field[:value]
          length = field[:length]
          if value.is_a? Integer
            raise 'Tarball header integer is negative.' if value < 0
            octal_value = value.to_s 8
            raise 'Tarball header integer is longer than allowed.' if octal_value.length > length - 1
            octal_value = octal_value.rjust length - 1, "0"
            output << "#{octal_value} "
          else
            raise 'Tarball header string is not ASCII.' unless value.ascii_only?
            output << value.ljust(length, "\0")
          end
        end
        output = output.ljust 512, "\0"
        checksum = output.bytes.sum
        octal_checksum = checksum.to_s 8
        justified_checksum = octal_checksum.rjust 7, '0'
        output[148...156] = "#{justified_checksum} "
        io.write output
      end

      def self.from_directory_entry directory_entry
        Header.new(
          ustar: true,
          path: directory_entry.path,
          size_data: 0,
          mode_data: directory_entry.mode.to_decimal,
          user_id_data: directory_entry.user_id,
          group_id_data: directory_entry.group_id,
          last_modified_data: directory_entry.last_modified.getutc.to_i,
          type_data: '5',
          link_path_data: ''
        )
      end

      def self.from_data_file_entry data_file_entry
        data = data_file_entry.data
        encoding = data.encoding
        size = data.force_encoding(Encoding::BINARY).length
        data.force_encoding encoding
        Header.new(
          ustar: true,
          path: data_file_entry.path,
          size_data: size,
          mode_data: data_file_entry.mode.to_decimal,
          user_id_data: data_file_entry.user_id,
          group_id_data: data_file_entry.group_id,
          last_modified_data: data_file_entry.last_modified.getutc.to_i,
          type_data: '0',
          link_path_data: ''
        )
      end

      def self.from_pathname_file_entry pathname_file_entry
        Header.new(
          ustar: true,
          path: pathname_file_entry.path,
          size_data: pathname_file_entry.pathname.size,
          mode_data: pathname_file_entry.mode.to_decimal,
          user_id_data: pathname_file_entry.user_id,
          group_id_data: pathname_file_entry.group_id,
          last_modified_data: pathname_file_entry.last_modified.getutc.to_i,
          type_data: '0',
          link_path_data: ''
        )
      end

      def self.from_data data
        raise "Incorrect amount of data for header reconstruction." unless data.length == 512
        io = StringIO.new data

        name_data = io.read(100).strip
        mode_data = io.read(8).strip.to_i 8
        user_id_data = io.read(8).strip.to_i 8
        group_id_data = io.read(8).strip.to_i 8
        size_data = io.read(12).strip.to_i 8
        last_modified_data = io.read(12).strip.to_i 8
        io.pos += 8 # Checksum
        type_data = io.read(1).strip
        link_path_data = io.read(100).strip
        ustar_indicator_data = io.read(6).strip
        io.pos += 2 # UStar version
        io.pos += 32 # User name
        io.pos += 32 # Group name
        io.pos += 8 # Major version
        io.pos += 8 # Minor version
        prefix_data = io.read(155).strip

        path = prefix_data.empty? ? name_data : "#{prefix_data}/#{name_data}"
        ustar = ustar_indicator_data == 'ustar'

        new(
          ustar: ustar,
          path: path,
          size_data: size_data,
          mode_data: mode_data,
          user_id_data: user_id_data,
          group_id_data: group_id_data,
          last_modified_data: last_modified_data,
          type_data: type_data,
          link_path_data: link_path_data
        )
      end
    end
  end
end