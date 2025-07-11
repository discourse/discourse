# frozen_string_literal: true

module DiscourseChatIntegration::Provider::TelegramProvider
  class TelegramCommandController < DiscourseChatIntegration::Provider::HookController
    requires_provider ::DiscourseChatIntegration::Provider::TelegramProvider::PROVIDER_NAME

    before_action :telegram_token_valid?, only: :command

    skip_before_action :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       only: :command

    def command
      # If it's a new message (telegram also sends hooks for other reasons that we don't care about)
      if params.key?("message")
        chat_id = params["message"]["chat"]["id"]

        message_text = process_command(params["message"])

        if message_text.present?
          message = {
            chat_id: chat_id,
            text: message_text,
            parse_mode: "html",
            disable_web_page_preview: true,
          }

          DiscourseChatIntegration::Provider::TelegramProvider.sendMessage(message)
        end
      elsif params.dig("channel_post", "text")&.include?("/getchatid")
        chat_id = params["channel_post"]["chat"]["id"]

        message_text =
          I18n.t(
            "chat_integration.provider.telegram.unknown_chat",
            site_title: CGI.escapeHTML(SiteSetting.title),
            chat_id: chat_id,
          )

        message = {
          chat_id: chat_id,
          text: message_text,
          parse_mode: "html",
          disable_web_page_preview: true,
        }

        DiscourseChatIntegration::Provider::TelegramProvider.sendMessage(message)
      end

      # Always give telegram a success message, otherwise we'll stop receiving webhooks
      data = { success: true }
      render json: data
    end

    def process_command(message)
      return unless message["text"] # No command to be processed

      chat_id = params["message"]["chat"]["id"]

      provider = DiscourseChatIntegration::Provider::TelegramProvider::PROVIDER_NAME

      channel =
        DiscourseChatIntegration::Channel
          .with_provider(provider)
          .with_data_value("chat_id", chat_id)
          .first

      text_key =
        if channel.nil?
          "unknown_chat"
        elsif !SiteSetting.chat_integration_telegram_enable_slash_commands ||
              !message["text"].start_with?("/")
          "silent"
        else
          ""
        end

      return "" if text_key == "silent"

      if text_key.present?
        return(
          I18n.t(
            "chat_integration.provider.telegram.#{text_key}",
            site_title: CGI.escapeHTML(SiteSetting.title),
            chat_id: chat_id,
          )
        )
      end

      tokens = message["text"].split(" ")

      tokens[0][0] = "" # Remove the slash from the first token
      tokens[0] = tokens[0].split("@")[0] # Remove the bot name from the command (necessary for group chats)

      ::DiscourseChatIntegration::Helper.process_command(channel, tokens)
    end

    def telegram_token_valid?
      params.require(:token)

      if SiteSetting.chat_integration_telegram_secret.blank? ||
           SiteSetting.chat_integration_telegram_secret != params[:token]
        raise Discourse::InvalidAccess.new
      end
    end
  end

  class TelegramEngine < ::Rails::Engine
    engine_name DiscourseChatIntegration::PLUGIN_NAME + "-telegram"
    isolate_namespace DiscourseChatIntegration::Provider::TelegramProvider
  end

  TelegramEngine.routes.draw { post "command/:token" => "telegram_command#command" }
end
