# frozen_string_literal: true

require_relative "integration"

module EminenceGrise
  module ActiveJob
    def self.included(base)
      base.include(Jobs::Integration)
    end
  end
end
