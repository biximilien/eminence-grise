# frozen_string_literal: true

require_relative "lib/eminence_grise/version"

Gem::Specification.new do |spec|
  spec.name = "eminence-grise"
  spec.version = EminenceGrise::VERSION
  spec.authors = ["Maxime 'biximilien' Gauthier"]
  spec.summary = "A small Ruby framework for sequential agentic task loops."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["lib/**/*.rb", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "rspec", "~> 3.13"
end
