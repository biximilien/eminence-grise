# frozen_string_literal: true

require_relative "adapter"

module EminenceGrise
  module Jobs
    # Shared implementation for job framework adapters.
    #
    # @api private
    module Integration
      # Extend the including class with the job DSL.
      def self.included(base)
        base.extend(ClassMethods)
      end

      # Process one task payload through the configured agent.
      #
      # @param task_payload [Task, Hash]
      # @return [Integer] number of tasks processed
      def perform(task_payload)
        Jobs::Adapter.new(
          agent: self.class.eminence_grise_agent_for(self),
          logger: self.class.eminence_grise_logger_for(self),
          wait_on_retry_at: self.class.eminence_grise_wait_on_retry_at
        ).call(task_payload)
      end

      # Class-level DSL mixed into job classes.
      module ClassMethods
        # Configure the agent factory for this job class.
        def eminence_grise_agent(&block)
          @eminence_grise_agent = block if block
          @eminence_grise_agent || superclass_setting(:eminence_grise_agent)
        end

        # Configure the logger factory for this job class.
        def eminence_grise_logger(&block)
          @eminence_grise_logger = block if block
          @eminence_grise_logger || superclass_setting(:eminence_grise_logger)
        end

        # Configure whether jobs should sleep until provider retry times.
        def eminence_grise_wait_on_retry_at(value = nil)
          @eminence_grise_wait_on_retry_at = value unless value.nil?
          return @eminence_grise_wait_on_retry_at unless @eminence_grise_wait_on_retry_at.nil?

          superclass_setting(:eminence_grise_wait_on_retry_at) || false
        end

        # Build the configured agent for a job instance.
        def eminence_grise_agent_for(instance)
          block = eminence_grise_agent
          raise ConfigurationError, "eminence_grise_agent must be configured" unless block

          instance.instance_exec(&block)
        end

        # Build the configured logger for a job instance.
        def eminence_grise_logger_for(instance)
          block = eminence_grise_logger
          block && instance.instance_exec(&block)
        end

        private

        def superclass_setting(name)
          return unless superclass.respond_to?(name)

          superclass.public_send(name)
        end
      end
    end
  end
end
