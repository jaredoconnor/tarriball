require 'fileutils'
require 'find'
require 'pathname'
require_relative 'service'

module Tarriball
  class << self
    def generate_entries_from_paths *paths
      new_service.generate_entries_from_paths(*paths)
    end

    def write_entries_to_io entries, io
      new_service.write_entries_to_io entries, io
    end

    def extract_from_io_into_path io, path
      new_service.extract_from_io_into_path io, path
    end

    def each_record_in_io io, &block
      new_service.each_record_in_io io, &block
    end

    def convert_path path
      new_service.convert_path path
    end

    private

    def new_service
      Service.new(
        File::SEPARATOR,
        FileUtils.method(:chmod),
        Find.method(:find),
        FileUtils.method(:mkdir_p),
        Pathname.method(:new),
        File.method(:open)
      )
    end
  end
end