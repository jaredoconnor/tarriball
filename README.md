# Tarriball

A Ruby tarball library that is hopefully only mildly terrible.

## About

I was unable to find a library that would easily do what I needed, so I reinvented the wheel.

## Todos

- Make this worthy of being used by anyone

## Installation

```
gem install tarriball
```

## Examples

### Creation

```
# Paths to directories or files that should be included in the archive.
some_path = 'some/path'
some_other_path = 'some/other/path'

# Generate entries.
entries = Tarriball.generate_entries_from_paths some_path, some_other_path

# Remove some entries.
entries.filter! do |entry|
  entry.input_path != 'some/path/to/exclude'
end

# Modify the entries.
entries.each do |entry|
  case entry
  when DirectoryEntry
    entry.mode = Mode.from_octal 700
  when FileEntry
    entry.mode = Mode.from_octal 600
  end
  entry.path.slice! 'some/'
end

# Manually add a file, from a path.
entries << PathFileEntry.new(
  file: 'an/input/file/path',
  path: 'an/archive/file/path'
)

# Manually add a file, with data.
entries << DataFileEntry.new(
  data: 'some data',
  path: 'another/archive/file/path'
)

# Manually add a directory.
entries << DirectoryEntry.new(
  path: 'an/archive/directory/path',
  mode: Mode.from_octal(750),
  user_id: 0,
  group_id: 0
)

# Create a plain TAR file.
File.open 'output.tar', 'wb' do |file|
  Tarriball.write_entries_to_io entries, file
end

# Create a Gzip file.
Zlib::GzipWriter.open 'output.tar.gz' do |file|
  Tarriball.write_entries_to_io entries, file
end
```

### Extraction

```
# Extract a plain TAR file.
File.open 'output.tar', 'rb' do |file|
  Tarriball.extract_from_io_into_path file, 'an/output/path'
end

# Extract a Gzip file.
Zlib::GzipWriter.open 'output.tar.gz' do |file|
  Tarriball.extract_from_io_into_path file, 'an/output/path'
end

# Iterate over contents.
Tarriball.each_record_in_io file do |record|
  if record.path == 'a/specific/path'
    record.extract_to_path 'an/output/path'
  else
    record.extract_into_path 'another/output/path'
  end
end
```

### Path Correction

TAR archives must use forward slashes for path separators inside records, regardless of what operating system was involved in their creation.
If your code will ever run on Windows, you may need to convert paths to/from the OS/TAR format.
The function below will help with this.
Note that this function does nothing to the input when executed on a POSIX operating system.
In other words, if `File::SEPARATOR` is a forward slash, the input path will be returned without any changes.

```
tar_path = Tarriball.convert_path 'a\windows\path'
windows_path = Tarriball.convert_path 'a/tar/path'
```