# frozen_string_literal: true

require_relative "integration"

module EminenceGrise
  # Sidekiq integration for processing one Eminence Grise task per job.
  #
  # Include `Sidekiq::Job` yourself, then include this module and configure an
  # agent with `eminence_grise_agent`.
  #
  # @example
  #   class AgentTaskWorker
  #     include Sidekiq::Job
  #     include EminenceGrise::Sidekiq
  #
  #     eminence_grise_agent do
  #       EminenceGrise::CodexAgent.new(working_directory: Rails.root.to_s)
  #     end
  #   end
  module Sidekiq
    # Mix the shared job integration into a Sidekiq worker class.
    def self.included(base)
      base.include(Jobs::Integration)
    end
  end
end
