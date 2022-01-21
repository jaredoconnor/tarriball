module Tarriball
  class Record
    DEFAULT_BLOCK_SIZE = 2048

    def initialize io, header, chmod_method, convert_path_method, mkdir_p_method, open_method
      @io = io
      @header = header
      @convert_path_method = convert_path_method
      @mkdir_p_method = mkdir_p_method
      @chmod_method = chmod_method
      @open_method = open_method
      @position = 0
      @closed = false
    end

    # Metadata

    def path
      @header.path
    end

    def mode
      Mode.from_decimal @header.mode_data
    end

    def size
      @header.size_data
    end

    def user_id
      @header.user_id_data
    end

    def group_id
      @header.group_id_data
    end

    def type
      @header.type_data
    end

    def link_path
      @header.link_path_data
    end

    def directory?
      @header.directory?
    end

    def file?
      @header.file?
    end

    # IO

    def eof?
      @position >= @header.size_data
    end

    def remaining_bytes
      @header.size_data - @position
    end

    def read length = remaining_bytes
      return nil if eof? || @closed
      real_length = length > remaining_bytes ? remaining_bytes : length
      @position += real_length
      @io.read real_length
    end

    def advance length = remaining_bytes, block_size: DEFAULT_BLOCK_SIZE
      return if eof?
      if @io.respond_to? :seek
        real_length = length > remaining_bytes ? remaining_bytes : length
        @position += real_length
        @io.seek real_length, IO::SEEK_CUR
      else
        until eof?
          read block_size
        end
      end
      nil
    end

    def close
      return if @closed
      advance
      overflow = @position % 512
      return nil if overflow == 0
      padding_length = 512 - overflow
      if @io.respond_to? :seek
        @io.seek padding_length, IO::SEEK_CUR
      else
        @io.read padding_length
      end
      nil
    end

    def extract_to_path path, block_size: DEFAULT_BLOCK_SIZE
      raise 'Data has already been read from the record.' unless @position == 0
      if directory?
        begin
          @chmod_method.call @header.mode_data, path
        rescue => e
          raise "Failed to change directory mode: #{e}"
        end
      elsif file?
        begin
          @open_method.call path, 'wb' do |file|
            file.write(read(block_size)) until eof?
          end
        rescue => e
          raise "Failed to extract file: #{e}"
        end
        begin
          @chmod_method.call @header.mode_data, path
        rescue => e
          raise "Failed to change file mode: #{e}"
        end
      else
        raise 'Only file and directory records can be extracted.'
      end
    end

    def extract_into_path path, block_size: DEFAULT_BLOCK_SIZE
      unless directory? || file?
        raise 'Only file and directory records can be extracted.'
      end
      if path.split('/').any? { |segment| segment == '..' }
        raise 'Archive record references a parent directory.'
      end
      os_path = @convert_path_method.call @header.path
      full_path = File.join path, os_path
      directory_path = directory? ? full_path : File.dirname(full_path)
      begin
        @mkdir_p_method.call directory_path
      rescue => e
        raise "Failed to create directory: #{e}"
      end
      extract_to_path full_path, block_size: block_size
    end
  end
end