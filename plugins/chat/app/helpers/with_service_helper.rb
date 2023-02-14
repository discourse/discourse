# frozen_string_literal: true
module Chat
  module WithServiceHelper
    def result
      @_result
    end

    def with_service(service, default_actions: true, **dependencies, &block)
      controller = self
      merged_block =
        proc do
          instance_eval(&controller.default_actions_for_service) if default_actions
          instance_eval(&(block || proc {}))
        end
      Chat::Endpoint.call(service, controller, **dependencies, &merged_block)
    end

    def run_service(service, dependencies)
      @_result = service.call(params.to_unsafe_h.merge(guardian: guardian, **dependencies.to_h))
    end

    def default_actions_for_service
      proc do
        on_success { render(json: success_json) }
        on_failure { render(json: failed_json, status: 422) }
        on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
        on_failed_contract do
          render(
            json:
              failed_json.merge(errors: result[:"result.contract.default"].errors.full_messages),
            status: 400,
          )
        end
      end
    end
  end
end
