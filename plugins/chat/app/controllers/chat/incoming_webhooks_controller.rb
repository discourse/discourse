# frozen_string_literal: true

module Chat
  class IncomingWebhooksController < ::ApplicationController
    requires_plugin Chat::PLUGIN_NAME

    WEBHOOK_MESSAGES_PER_MINUTE_LIMIT = 10

    skip_before_action :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       :redirect_to_profile_if_required

    before_action :validate_payload

    def create_message
      debug_payload

      process_webhook_payload(text: params[:text], key: params[:key])
    end

    # See https://api.slack.com/reference/messaging/payload for the
    # slack message payload format. For now we only support the
    # text param, which we preprocess lightly to remove the slack-isms
    # in the formatting.
    def create_message_slack_compatible
      debug_payload

      # See note in validate_payload on why this is needed
      attachments =
        if params[:payload].present?
          payload = params[:payload]
          if String === payload
            payload = JSON.parse(payload)
            payload.deep_symbolize_keys!
          end
          payload[:attachments]
        else
          params[:attachments]
        end

      if params[:text].present?
        text = Chat::SlackCompatibility.process_text(params[:text])
      else
        text = Chat::SlackCompatibility.process_legacy_attachments(attachments)
      end

      process_webhook_payload(text: text, key: params[:key])
    rescue JSON::ParserError
      raise Discourse::InvalidParameters
    end

    private

    def process_webhook_payload(text:, key:)
      webhook = find_and_rate_limit_webhook(key)
      webhook.chat_channel.add(Discourse.system_user)

      Chat::CreateMessage.call(
        params: {
          chat_channel_id: webhook.chat_channel_id,
          message: text,
        },
        guardian: Discourse.system_user.guardian,
        incoming_chat_webhook: webhook,
      ) do
        on_success { render json: success_json }
        on_failure { render(json: failed_json, status: 422) }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages)
        end
        on_failed_policy(:no_silenced_user) { raise Discourse::InvalidAccess }
        on_model_not_found(:channel) { raise Discourse::NotFound }
        on_failed_policy(:allowed_to_join_channel) { raise Discourse::InvalidAccess }
        on_model_not_found(:channel_membership) { raise Discourse::InvalidAccess }
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
      end
    end

    def find_and_rate_limit_webhook(key)
      webhook = Chat::IncomingWebhook.includes(:chat_channel).find_by(key: key)
      raise Discourse::NotFound unless webhook

      # Rate limit to 10 messages per-minute. We can move to a site setting in the future if needed.
      RateLimiter.new(
        nil,
        "incoming_chat_webhook_#{webhook.id}",
        WEBHOOK_MESSAGES_PER_MINUTE_LIMIT,
        1.minute,
      ).performed!
      webhook
    end

    # The webhook POST body can be in 3 different formats:
    #
    # * { text: "message text" }, which is the most basic method, and also mirrors Slack payloads
    # * { attachments: [ text: "message text" ] }, which is a variant of Slack payloads using legacy attachments
    # * { payload: "<JSON STRING>", attachments: null, text: null }, where JSON STRING can look
    #   like the `attachments` example above (along with other attributes), which is fired by OpsGenie
    def validate_payload
      params.require(:key)

      if !params[:text] && !params[:payload] && !params[:attachments]
        raise Discourse::InvalidParameters
      end
    end

    def debug_payload
      return if !SiteSetting.chat_debug_webhook_payloads
      Rails.logger.warn(
        "Debugging chat webhook payload for endpoint #{params[:key]}: " +
          JSON.dump(
            { payload: params[:payload], attachments: params[:attachments], text: params[:text] },
          ),
      )
    end
  end
end
