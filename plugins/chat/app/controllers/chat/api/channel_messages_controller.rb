# frozen_string_literal: true

class Chat::Api::ChannelMessagesController < Chat::ApiController
  def index
    ::Chat::ListChannelMessages.call(service_params) do |result|
      on_success { render_serialized(result, ::Chat::MessagesSerializer, root: false) }
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_failed_policy(:target_message_exists) { raise Discourse::NotFound }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def destroy
    Chat::TrashMessage.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def bulk_destroy
    Chat::TrashMessages.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:messages) { raise Discourse::NotFound }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def restore
    Chat::RestoreMessage.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def update
    Chat::UpdateMessage.call(service_params) do
      on_success { |message:| render json: success_json.merge(message_id: message.id) }
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_model_errors(:message) do |model|
        render_json_error(model.errors.map(&:full_message).join(", "))
      end
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def create
    Chat::MessageRateLimiter.run!(current_user)

    Chat::CreateMessage.call(service_params) do
      on_success do |message_instance:|
        render json: success_json.merge(message_id: message_instance.id)
      end
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:no_silenced_user) { raise Discourse::InvalidAccess }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_policy(:allowed_to_join_channel) { raise Discourse::InvalidAccess }
      on_model_not_found(:membership) { raise Discourse::NotFound }
      on_failed_policy(:ensure_reply_consistency) { raise Discourse::NotFound }
      on_failed_policy(:allowed_to_create_message_in_channel) do |policy|
        render_json_error(policy.reason)
      end
      on_failed_policy(:ensure_valid_thread_for_channel) do
        render_json_error(I18n.t("chat.errors.thread_invalid_for_channel"))
      end
      on_failed_policy(:ensure_thread_matches_parent) do
        render_json_error(I18n.t("chat.errors.thread_does_not_match_parent"))
      end
      on_model_errors(:message_instance) do |model|
        render_json_error(model.errors.map(&:full_message).join(", "))
      end
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
