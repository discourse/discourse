# frozen_string_literal: true
module Chat
  module WithServiceHelper
    def result
      @_result
    end

    def with_service(service, default_actions: true, **dependencies, &block)
      object = self
      merged_block =
        proc do
          instance_exec(&object.method(:default_actions_for_service).call) if default_actions
          instance_exec(&(block || proc {}))
        end
      Chat::ServiceRunner.call(service, object, **dependencies, &merged_block)
    end

    def run_service(service, dependencies)
      @_result = service.call(params.to_unsafe_h.merge(guardian: guardian, **dependencies))
    end

    def default_actions_for_service
      proc {}
    end
  end
end
