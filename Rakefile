# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "rspec/core/rake_task"
require "yard"

# YARD's File.relative_path helper can see Windows paths with UTF-8 bytes but
# US-ASCII encoding when the workspace path contains non-ASCII characters.
class File
  def self.relative_path(from, to)
    from = expand_utf8_path(from).split(SEPARATOR)
    to = expand_utf8_path(to).split(SEPARATOR)
    from.length.times do
      break if from[0] != to[0]

      from.shift
      to.shift
    end
    from.pop
    join(*(from.map { RELATIVE_PARENTDIR } + to))
  end

  def self.expand_utf8_path(path)
    utf8_path(expand_path(utf8_path(path)))
  end

  def self.utf8_path(path)
    path = path.dup
    path.force_encoding(Encoding::UTF_8) unless path.encoding == Encoding::UTF_8
    path.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
  end
end

RSpec::Core::RakeTask.new(:spec)
YARD::Rake::YardocTask.new(:doc)

task default: :spec
