# frozen_string_literal: true

module DiscourseWorkflows
  class Executor
    module WaitHandlers
      class Base
        class << self
          attr_reader :wait_type

          def handles_wait_type(type)
            @wait_type = type.to_s
            WaitHandlers.register(self)
          end

          def waiting_scope(scope = DiscourseWorkflows::Execution.all)
            raise ArgumentError, "#{name} must declare a wait_type" if wait_type.blank?

            scope.where(status: :waiting).where("waiting_config->>'wait_type' = ?", wait_type)
          end

          def find_waiting_execution_by_resume_token(
            token,
            scope = DiscourseWorkflows::Execution.all
          )
            waiting_scope(scope).where("waiting_config ? 'resume_token'").where(
              "waiting_config->>'resume_token' = ?",
              token,
            )
          end

          def handles_execution?(execution)
            WaitHandlers.for_execution(execution) == self
          rescue ArgumentError
            false
          end

          def on_timeout(execution)
            return execution.fail_with_timeout! if fail_on_timeout?(execution)

            DiscourseWorkflows::Executor.resume(execution, timeout_response_items(execution))
          end

          def timeout_response_items(_execution)
            raise NotImplementedError, "#{name} must implement .timeout_response_items"
          end

          def waiting_step(execution)
            execution.execution_data&.find_step(
              node_id: execution.waiting_node_id,
              status: Executor::Step::WAITING,
            )
          end

          def waiting_input_items(execution)
            waiting_step(execution)&.dig("input") || [{ "json" => {} }]
          end

          private

          def fail_on_timeout?(execution)
            execution.waiting_config&.dig("timeout_action") == WaitHandlers::TIMEOUT_ACTION_FAIL
          end
        end

        def initialize(persistence:, context:, runtime:)
          @persistence = persistence
          @context = context
          @runtime = runtime
        end

        def pause!(wait)
          raise NotImplementedError
        end

        private

        def pause_execution!(node, waiting_until: nil, extra_config: {})
          @persistence.pause_waiting_execution!(
            node: node,
            waiting_until: waiting_until,
            extra_config: extra_config,
          )
        end

        def step
          @runtime.waiting_step
        end

        def node
          @runtime.waiting_node
        end

        def execution
          @persistence.execution
        end
      end
    end
  end
end
