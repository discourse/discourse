# frozen_string_literal: true

class Chat::Api::ChannelThreadMessagesController < Chat::ApiController
  def index
    with_service(::Chat::ListChannelThreadMessages) do
      on_success do
        render_serialized(
          result,
          ::Chat::MessagesSerializer,
          root: false,
          include_thread_preview: false,
          include_thread_original_message: false,
        )
      end

      on_failed_policy(:ensure_thread_enabled) { raise Discourse::NotFound }
      on_failed_policy(:target_message_exists) { raise Discourse::NotFound }
      on_failed_policy(:can_view_thread) { raise Discourse::InvalidAccess }
      on_model_not_found(:thread) { raise Discourse::NotFound }
    end
  end
end
