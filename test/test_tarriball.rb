require 'fileutils'
require 'find'
require 'helper'
require 'pathname'
require 'set'

class TestTarriball < Minitest::Test
  EXAMPLE_PATH = File.join 'test', 'example'

  def test_version
    refute_nil Tarriball::VERSION
  end

  def test_convert_path_for_windows
    service = Tarriball::Service.new(
      '\\',
      FileUtils.method(:chmod),
      Find.method(:find),
      FileUtils.method(:mkdir_p),
      Pathname.method(:new),
      File.method(:open)
    )
    input = 'a/b\\c/d'
    output = service.convert_path input
    assert_equal 'a\\b/c\\d', output, 'Path separators did not change correctly.'
  end

  def test_convert_path_for_posix
    service = Tarriball::Service.new(
      '/',
      FileUtils.method(:chmod),
      Find.method(:find),
      FileUtils.method(:mkdir_p),
      Pathname.method(:new),
      File.method(:open)
    )
    input = 'a/b\\c/d'
    output = service.convert_path input
    assert_equal input, output, 'Path separators changed.'
  end

  def test_create
    descendant_paths = Find.find(EXAMPLE_PATH).to_set { |path| Pathname.new(path).cleanpath.to_s }
    entries = Tarriball.generate_entries_from_paths EXAMPLE_PATH
    assert_equal descendant_paths.count, entries.count, 'Invalid number of entries.'

    test_path = File.join 'tmp', 'test-create'
    FileUtils.rm_rf test_path
    FileUtils.mkdir_p test_path

    archive_path = File.join test_path, 'archive.tar.txt'
    File.open archive_path, 'wb' do |file|
      Tarriball.write_entries_to_io entries, file
    end

    output = `tar -tf '#{archive_path}'`
    raise 'Failed to get archive contents.' unless $?.success?
    output_paths = output.lines.to_set { |line| Pathname.new(line.chomp).cleanpath.to_s }
    assert_equal descendant_paths, output_paths, 'Archive paths do not match example paths.'
  end

  def test_extract
    test_path = File.join 'tmp', 'test-extract'
    archive_path = File.join test_path, 'archive.tar'
    extracted_path = File.join test_path, 'test', 'example'

    FileUtils.rm_rf test_path
    FileUtils.mkdir_p extracted_path

    `tar -cf '#{archive_path}' '#{EXAMPLE_PATH}'`
    raise 'Failed to create archive.' unless $?.success?

    File.open archive_path do |file|
      Tarriball.extract_from_io_into_path file, test_path
    end

    example_paths = Find.find(EXAMPLE_PATH).to_set
    extracted_paths = Find.find(extracted_path).to_set do |path|
      Pathname.new(path).relative_path_from(test_path).to_s
    end
    assert_equal example_paths, extracted_paths, 'Extracted paths do not match example paths.'
  end
end
