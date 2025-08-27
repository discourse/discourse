# frozen_string_literal: true

module DiscourseChatIntegration::Provider::MattermostProvider
  class MattermostCommandController < DiscourseChatIntegration::Provider::HookController
    requires_provider ::DiscourseChatIntegration::Provider::MattermostProvider::PROVIDER_NAME

    before_action :mattermost_token_valid?, only: :command

    skip_before_action :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       only: :command

    def command
      text = process_command(params)

      render json: { response_type: "ephemeral", text: text }
    end

    def process_command(params)
      tokens = params[:text].split(" ")

      # channel name fix
      channel_id =
        case params[:channel_name]
        when "directmessage"
          "@#{params[:user_name]}"
        when "privategroup"
          params[:channel_id]
        else
          "##{params[:channel_name]}"
        end

      provider = DiscourseChatIntegration::Provider::MattermostProvider::PROVIDER_NAME

      channel =
        DiscourseChatIntegration::Channel
          .with_provider(provider)
          .with_data_value("identifier", channel_id)
          .first

      # Create channel if doesn't exist
      channel ||=
        DiscourseChatIntegration::Channel.create!(
          provider: provider,
          data: {
            identifier: channel_id,
          },
        )

      ::DiscourseChatIntegration::Helper.process_command(channel, tokens)
    end

    def mattermost_token_valid?
      params.require(:token)

      if SiteSetting.chat_integration_mattermost_incoming_webhook_token.blank? ||
           SiteSetting.chat_integration_mattermost_incoming_webhook_token != params[:token]
        raise Discourse::InvalidAccess.new
      end
    end
  end

  class MattermostEngine < ::Rails::Engine
    engine_name DiscourseChatIntegration::PLUGIN_NAME + "-mattermost"
    isolate_namespace DiscourseChatIntegration::Provider::MattermostProvider
  end

  MattermostEngine.routes.draw { post "command" => "mattermost_command#command" }
end
