require_relative 'internal/entry'

module Tarriball
  class DirectoryEntry < Internal::Entry
    def initialize path:, mode: Mode::DIRECTORY_DEFAULT, user_id: Internal::Entry::DEFAULT_USER_ID, group_id: Internal::Entry::DEFAULT_GROUP_ID, last_modified: Time.now
      super(path: path, mode: mode, user_id: user_id, group_id: group_id, last_modified: last_modified)
    end
  end

  class DataFileEntry < Internal::Entry
    attr_accessor :data
    def initialize data:, path:, mode: Mode::FILE_DEFAULT, user_id: Internal::Entry::DEFAULT_USER_ID, group_id: Internal::Entry::DEFAULT_GROUP_ID, last_modified: Time.now
      @data = data
      super(path: path, mode: mode, user_id: user_id, group_id: group_id, last_modified: last_modified)
    end
  end

  class PathnameFileEntry < Internal::Entry
    attr_accessor :pathname, :block_size
    def initialize pathname:, path:, block_size: DEFAULT_BLOCK_SIZE, mode: Mode::FILE_DEFAULT, user_id: Internal::Entry::DEFAULT_USER_ID, group_id: Internal::Entry::DEFAULT_GROUP_ID, last_modified: Time.now
      @pathname = pathname
      @block_size = block_size
      super(path: path, mode: mode, user_id: user_id, group_id: group_id, last_modified: last_modified)
    end
    DEFAULT_BLOCK_SIZE = 2048
  end
end