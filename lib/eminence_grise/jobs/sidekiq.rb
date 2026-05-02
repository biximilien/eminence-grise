# frozen_string_literal: true

require_relative "integration"

module EminenceGrise
  module Sidekiq
    def self.included(base)
      base.include(Jobs::Integration)
    end
  end
end
