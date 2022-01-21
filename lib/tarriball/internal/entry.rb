require_relative 'header'

module Tarriball
  module Internal
    class Entry
      DEFAULT_USER_ID = 0
      DEFAULT_GROUP_ID = 0
      attr_accessor :path, :mode, :user_id, :group_id, :last_modified
      def initialize path:, mode:, user_id: DEFAULT_USER_ID, group_id: DEFAULT_GROUP_ID, last_modified: Time.now
        @path = path
        @mode = mode
        @user_id = user_id
        @group_id = group_id
        @last_modified = last_modified
      end
    end
  end
end