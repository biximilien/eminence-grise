# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "rspec/core/rake_task"
require "yard"

# YARD's File.relative_path helper can see Windows paths with UTF-8 bytes but
# US-ASCII encoding when the workspace path contains non-ASCII characters.
class File
  def self.relative_path(from, to)
    from = expand_path(from).encode(Encoding::UTF_8, invalid: :replace, undef: :replace).split(SEPARATOR)
    to = expand_path(to).encode(Encoding::UTF_8, invalid: :replace, undef: :replace).split(SEPARATOR)
    from.length.times do
      break if from[0] != to[0]

      from.shift
      to.shift
    end
    from.pop
    join(*(from.map { RELATIVE_PARENTDIR } + to))
  end
end

RSpec::Core::RakeTask.new(:spec)
YARD::Rake::YardocTask.new(:doc)

task default: :spec
