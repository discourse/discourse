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

  def with_service(service, &block)
    Chat::Endpoint.call(service, &block)
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
end
