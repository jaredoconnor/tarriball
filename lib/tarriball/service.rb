require_relative 'entries'
require_relative 'internal/header'

module Tarriball
  class Service
    def initialize file_separator, chmod_method, find_method, mkdir_p_method, new_pathname_method, open_method
      @file_separator = file_separator
      @chmod_method = chmod_method
      @find_method = find_method
      @mkdir_p_method = mkdir_p_method
      @new_pathname_method = new_pathname_method
      @open_method = open_method
    end

    def convert_path path
      return path if @file_separator == '/'
      characters = path.chars.map do |character|
        case character
        when '/'
          '\\'
        when '\\'
          '/'
        else
          character
        end
      end
      characters.join
    end

    def generate_entries_from_paths *paths
      entries = []
      paths.each do |path|
        @find_method.call(path).each do |descendant_path|
          entry_path = convert_path descendant_path
          descendant_pathname = @new_pathname_method.call descendant_path
          stat = descendant_pathname.stat
          user_id = stat.uid
          group_id = stat.gid
          mode = Mode.from_decimal stat.mode
          if descendant_pathname.directory?
            entries << DirectoryEntry.new(
              path: entry_path,
              mode: mode,
              user_id: user_id,
              group_id: group_id,
              last_modified: stat.mtime
            )
          elsif descendant_pathname.file?
            entries << PathnameFileEntry.new(
              pathname: descendant_pathname,
              path: entry_path,
              mode: mode,
              user_id: user_id,
              group_id: group_id,
              last_modified: stat.mtime
            )
          end
        end
      end
      entries.sort_by! { |entry| entry.path }
    end
  
    def write_entries_to_io entries, io
      sorted_entries = entries.sort_by do |entry|
        path = entry.path
        raise "Tarball entry contains a non-ASCII path: #{path}" unless path.ascii_only?
        if path.split('/').any? { |segment| segment == '..' }
          raise "Tarball entry path references a parent directory: #{path}"
        end
        path
      end
      sorted_entries.each do |entry|
        written = 0
        case entry
        when DirectoryEntry
          header = Internal::Header.from_directory_entry entry
          header.write_to_io io
        when DataFileEntry
          header = Internal::Header.from_data_file_entry entry
          header.write_to_io io
          size = header.size_data
          if size > 0
            data = entry.data
            encoding = data.encoding
            data.force_encoding Encoding::BINARY
            written = io.write data
            data.force_encoding encoding
          end
        when PathnameFileEntry
          header = Internal::Header.from_pathname_file_entry entry
          header.write_to_io io
          if header.size_data > 0
            block_size = entry.block_size
            entry.pathname.open 'rb' do |file|
              until file.eof?
                written += io.write(file.read(block_size))
              end
            end
          end
        end
        if written > 0
          remaining = 512 - written % 512
          io.write(''.rjust(remaining, "\0"))
        end
      end
      io.write(''.rjust(1024, "\0"))
      nil
    end
  
    def extract_from_io_into_path io, path
      each_record_in_io io do |record|
        next unless record.file? || record.directory?
        record.extract_into_path path
      end
    end
  
    def each_record_in_io io, &block
      blank_records = 0
      loop do
        data = io.read 512
        if data.strip.empty?
          blank_records += 1
          break if blank_records > 1
        else
          header = Internal::Header.from_data data
          record = Record.new io, header, @chmod_method, method(:convert_path), @mkdir_p_method, @open_method
          block.call record
          record.close
        end
      end
    end
  end
end