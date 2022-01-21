require_relative 'lib/tarriball/version'

Gem::Specification.new do |specification|
  specification.name = 'tarriball'
  specification.version = Tarriball::VERSION
  specification.required_ruby_version = '>= 3.0.0'

  specification.summary = 'A tarball library that is hopefully only mildly terrible.'
  specification.description = 'A library, for creating and extracting tarball files, that is hopefully only mildly terrible.'
  specification.homepage = 'https://github.com/jaredoconnor/tarriball'
  specification.license = 'MIT'

  specification.authors = ["Jared O'Connor"]
  specification.email = ['jaredoconnor@hotmail.com']

  specification.metadata['homepage_uri'] = specification.homepage
  specification.metadata['source_code_uri'] = specification.homepage

  specification.files = `git ls-files lib -z`.split "\x0"
end
