# frozen_string_literal: true

require_relative "integration"

module EminenceGrise
  # ActiveJob integration for processing one Eminence Grise task per job.
  #
  # Include this alongside your application job base class and configure an
  # agent with `eminence_grise_agent`.
  #
  # @example
  #   class AgentTaskJob < ApplicationJob
  #     include EminenceGrise::ActiveJob
  #
  #     eminence_grise_agent do
  #       EminenceGrise::CodexAgent.new(working_directory: Rails.root.to_s)
  #     end
  #   end
  module ActiveJob
    # Mix the shared job integration into an ActiveJob class.
    def self.included(base)
      base.include(Jobs::Integration)
    end
  end
end
