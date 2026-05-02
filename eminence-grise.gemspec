# frozen_string_literal: true

require_relative "lib/eminence_grise/version"

Gem::Specification.new do |spec|
  spec.name = "eminence-grise"
  spec.version = EminenceGrise::VERSION
  spec.authors = ["Maxime 'biximilien' Gauthier"]
  spec.summary = "A small Ruby framework for sequential agentic task loops."
  spec.homepage = "https://github.com/biximilien/eminence-grise"
  spec.license = "Apache-2.0"
  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "#{spec.homepage}/tree/main",
    "documentation_uri" => "https://www.rubydoc.info/gems/eminence-grise"
  }
  spec.required_ruby_version = ">= 3.2"

  spec.bindir = "exe"
  spec.executables = ["eminence-grise"]
  spec.files = Dir["exe/*", "lib/**/*.rb", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "yard", "~> 0.9"
end
