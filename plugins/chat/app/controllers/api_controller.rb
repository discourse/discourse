# frozen_string_literal: true

class Chat::Api < Chat::ChatBaseController
  before_action :ensure_logged_in
  before_action :ensure_can_chat

  def result
    @_result
  end

  private

  def ensure_can_chat
    raise Discourse::NotFound unless SiteSetting.chat_enabled
    guardian.ensure_can_chat!
  end

  def with_service(service, default_actions: true, &block)
    default_block = default_actions_for_service
    merged_block =
      proc do |instance|
        instance.instance_eval(&default_block) if default_actions
        instance.instance_eval(&(block || proc {}))
      end
    Chat::Endpoint.call(service, &merged_block)
  end

  def handle_service_result(result, serializer_object: nil, serializer: nil, serializer_data: {})
    if result.success?
      if serializer_object && serializer
        return(render_serialized(serializer_object, serializer, **serializer_data))
      else
        return { json: success_json } if result.success?
      end
    end

    raise Discourse::InvalidAccess if result[:"result.policy.invalid_access"].failure?

    if result[:"contract.failed"]
      return({ json: failed_json.merge(errors: contract.errors.full_messages), status: 400 })
    end

    { json: failed_json }
  end

  def wrap_service(result)
    return yield(true, result, nil) if result.success?

    raise Discourse::InvalidAccess if result[:"result.policy.invalid_access"].failure?

    if result[:"contract.failed"]
      yield(
        false,
        result,
        { json: failed_json.merge(errors: contract.errors.full_messages), status: 400 }
      )
    end

    yield(false, result, { json: failed_json })
  end

  def default_actions_for_service
    proc do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_contract do
        render(json: failed_json.merge(errors: result[:contract].errors.full_messages), status: 400)
      end
    end
  end
end
