# frozen_string_literal: true

require_relative "adapter"

module EminenceGrise
  module Jobs
    module Integration
      def self.included(base)
        base.extend(ClassMethods)
      end

      def perform(task_payload)
        Jobs::Adapter.new(
          agent: self.class.eminence_grise_agent_for(self),
          logger: self.class.eminence_grise_logger_for(self),
          wait_on_retry_at: self.class.eminence_grise_wait_on_retry_at
        ).call(task_payload)
      end

      module ClassMethods
        def eminence_grise_agent(&block)
          @eminence_grise_agent = block if block
          @eminence_grise_agent || superclass_setting(:eminence_grise_agent)
        end

        def eminence_grise_logger(&block)
          @eminence_grise_logger = block if block
          @eminence_grise_logger || superclass_setting(:eminence_grise_logger)
        end

        def eminence_grise_wait_on_retry_at(value = nil)
          @eminence_grise_wait_on_retry_at = value unless value.nil?
          return @eminence_grise_wait_on_retry_at unless @eminence_grise_wait_on_retry_at.nil?

          superclass_setting(:eminence_grise_wait_on_retry_at) || false
        end

        def eminence_grise_agent_for(instance)
          block = eminence_grise_agent
          raise ConfigurationError, "eminence_grise_agent must be configured" unless block

          instance.instance_exec(&block)
        end

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
