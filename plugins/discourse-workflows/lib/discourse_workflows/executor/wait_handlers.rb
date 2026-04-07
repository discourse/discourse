# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module WaitHandlers
      TIMEOUT_ACTION_FAIL = "fail"
      TIMEOUT_ACTION_DENY = "deny"

      class << self
        def register(handler_class)
          type = handler_class.wait_type
          if type.blank?
            raise ArgumentError, "Handler #{handler_class.name} must declare a wait_type"
          end

          existing = registry[type]
          if existing.present? && existing != handler_class
            raise ArgumentError, "Wait type #{type} is already registered to #{existing.name}"
          end

          registry[type] = handler_class
        end

        def for(type)
          normalized_type = normalize_type(type)
          registry[normalized_type] || load_handler(normalized_type) || unknown_wait_type!(type)
        end

        def for_execution(execution)
          self.for(execution.waiting_config&.dig("wait_type"))
        end

        private

        def registry
          @registry ||= {}
        end

        def load_handler(type)
          handler_class_name = "DiscourseWorkflows::Executor::WaitHandlers::#{type.camelize}"
          handler_class = handler_class_name.safe_constantize
          return unless handler_class.respond_to?(:wait_type)

          handler_class if handler_class.wait_type == type
        end

        def normalize_type(type)
          type.to_s.presence || unknown_wait_type!(type)
        end

        def unknown_wait_type!(type)
          raise ArgumentError, "Unknown wait type: #{type.inspect}"
        end
      end
    end
  end
end
