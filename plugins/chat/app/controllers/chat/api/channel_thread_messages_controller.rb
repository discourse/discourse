# frozen_string_literal: true

class Chat::Api::ChannelThreadMessagesController < Chat::ApiController
  def index
    ::Chat::ListChannelThreadMessages.call(service_params) do |result|
      on_success do
        render_serialized(
          result,
          ::Chat::MessagesSerializer,
          root: false,
          include_thread_preview: false,
          include_thread_original_message: false,
        )
      end
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:target_message_exists) { raise Discourse::NotFound }
      on_failed_policy(:can_view_thread) { raise Discourse::InvalidAccess }
      on_model_not_found(:thread) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
