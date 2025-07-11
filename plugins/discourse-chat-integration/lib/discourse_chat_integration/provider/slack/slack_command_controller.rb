# frozen_string_literal: true

module DiscourseChatIntegration::Provider::SlackProvider
  class SlackCommandController < DiscourseChatIntegration::Provider::HookController
    requires_provider ::DiscourseChatIntegration::Provider::SlackProvider::PROVIDER_NAME

    before_action :slack_token_valid?, only: :command
    before_action :slack_payload_token_valid?, only: :interactive

    skip_before_action :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       only: %i[command interactive]

    def command
      message = process_command(params)

      render json: message
    end

    def interactive
      json = JSON.parse(params[:payload], symbolize_names: true)
      process_interactive(json)
      head :ok
    end

    private

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

      provider = DiscourseChatIntegration::Provider::SlackProvider::PROVIDER_NAME

      channel =
        DiscourseChatIntegration::Channel
          .with_provider(provider)
          .with_data_value("identifier", channel_id)
          .first

      channel ||=
        DiscourseChatIntegration::Channel.create!(
          provider: provider,
          data: {
            identifier: channel_id,
          },
        )

      if tokens[0] == "post"
        process_post_request(
          channel,
          tokens,
          params[:channel_id],
          channel_id,
          params[:response_url],
        )
      else
        { text: ::DiscourseChatIntegration::Helper.process_command(channel, tokens) }
      end
    end

    def process_post_request(channel, tokens, slack_channel_id, channel_name, response_url)
      if SiteSetting.chat_integration_slack_access_token.empty?
        return { text: I18n.t("chat_integration.provider.slack.transcript.api_required") }
      end

      Scheduler::Defer.later "Processing slack transcript request" do
        response =
          build_post_request_response(channel, tokens, slack_channel_id, channel_name, response_url)
        http = DiscourseChatIntegration::Provider::SlackProvider.slack_api_http
        req = Net::HTTP::Post.new(URI(response_url), "Content-Type" => "application/json")
        req.body = response.to_json
        http.request(req)
      end

      { text: I18n.t("chat_integration.provider.slack.transcript.loading") }
    end

    def build_post_request_response(channel, tokens, slack_channel_id, channel_name, response_url)
      requested_messages = nil
      first_message_ts = nil
      requested_thread_ts = nil

      thread_url_regex =
        /^https:\/\/\S+\.slack\.com\/archives\/\S+\/p[0-9]{16}\?thread_ts=([0-9]{10}.[0-9]{6})\S*$/
      slack_url_regex = /^https:\/\/\S+\.slack\.com\/archives\/\S+\/p([0-9]{16})\/?$/

      if tokens.size > 2 && tokens[1] == "thread" && match = slack_url_regex.match(tokens[2])
        requested_thread_ts = match.captures[0].insert(10, ".")
      elsif tokens.size > 1 && match = thread_url_regex.match(tokens[1])
        requested_thread_ts = match.captures[0]
      elsif tokens.size > 1 && match = slack_url_regex.match(tokens[1])
        first_message_ts = match.captures[0].insert(10, ".")
      elsif tokens.size > 1
        begin
          requested_messages = Integer(tokens[1], 10)
        rescue ArgumentError
          return { text: I18n.t("chat_integration.provider.slack.parse_error") }
        end
      end

      error_key = "chat_integration.provider.slack.transcript.error"

      unless transcript =
               SlackTranscript.new(
                 channel_name: channel_name,
                 channel_id: slack_channel_id,
                 requested_thread_ts: requested_thread_ts,
               )
        return { text: I18n.t(error_key) }
      end
      return { text: I18n.t("#{error_key}_users") } unless transcript.load_user_data
      return { text: I18n.t("#{error_key}_history") } unless transcript.load_chat_history

      if first_message_ts
        unless transcript.set_first_message_by_ts(first_message_ts)
          return { text: I18n.t("#{error_key}_ts") }
        end
      elsif requested_messages
        transcript.set_first_message_by_index(-requested_messages)
      else
        transcript.set_first_message_by_index(-10) unless transcript.guess_first_message
      end

      transcript.build_slack_ui
    end

    def process_interactive(json)
      Scheduler::Defer.later "Processing slack transcript update" do
        http = DiscourseChatIntegration::Provider::SlackProvider.slack_api_http

        if json[:type] == "block_actions" && json[:actions][0][:action_id] == "null_action"
          # Do nothing
        elsif json[:type] == "message_action" && json[:message][:thread_ts]
          # Context menu used on a threaded message
          transcript =
            SlackTranscript.new(
              channel_name: "##{json[:channel][:name]}",
              channel_id: json[:channel][:id],
              requested_thread_ts: json[:message][:thread_ts],
            )

          # Send a loading modal within 3 seconds:
          req =
            Net::HTTP::Post.new(
              "https://slack.com/api/views.open",
              "Content-Type" => "application/json",
              "Authorization" => "Bearer #{SiteSetting.chat_integration_slack_access_token}",
            )
          req.body = { trigger_id: json[:trigger_id], view: transcript.build_modal_ui }.to_json
          response = http.request(req)
          view_id = JSON.parse(response.body).dig("view", "id")

          # Now load the transcript
          error_view = generate_error_view("users") unless transcript.load_user_data
          error_view = generate_error_view("history") unless transcript.load_chat_history

          # Then update the modal with the transcript link:
          req =
            Net::HTTP::Post.new(
              "https://slack.com/api/views.update",
              "Content-Type" => "application/json",
              "Authorization" => "Bearer #{SiteSetting.chat_integration_slack_access_token}",
            )
          req.body = { view_id: view_id, view: error_view || transcript.build_modal_ui }.to_json
          response = http.request(req)
        else
          # Button clicked in one of our interactive messages
          req = Net::HTTP::Post.new(URI(json[:response_url]), "Content-Type" => "application/json")
          req.body = build_interactive_response(json).to_json
          response = http.request(req)
        end
      end
    end

    def build_interactive_response(json)
      requested_thread = first_message = last_message = nil

      if json[:type] == "message_action" # Slack "Shortcut" (for non-threaded messages)
        first_message = json[:message][:ts]
      else # Clicking buttons in our transcript UI message
        action_name = json[:actions][0][:name]

        constant_val = json[:callback_id]
        changed_val = json[:actions][0][:selected_options][0][:value]

        first_message = (action_name == "first_message") ? changed_val : constant_val
        last_message = (action_name == "first_message") ? constant_val : changed_val
      end

      error_key = "chat_integration.provider.slack.transcript.error"

      unless transcript =
               SlackTranscript.new(
                 channel_name: "##{json[:channel][:name]}",
                 channel_id: json[:channel][:id],
                 requested_thread_ts: requested_thread,
               )
        return { text: I18n.t(error_key) }
      end
      return { text: I18n.t("#{error_key}_users") } unless transcript.load_user_data
      return { text: I18n.t("#{error_key}_history") } unless transcript.load_chat_history

      if first_message
        unless transcript.set_first_message_by_ts(first_message)
          return { text: I18n.t("#{error_key}_ts") }
        end
      end

      if last_message
        unless transcript.set_last_message_by_ts(last_message)
          return { text: I18n.t("#{error_key}_ts") }
        end
      end

      transcript.build_slack_ui
    end

    def generate_error_view(type = nil)
      error_key = "chat_integration.provider.slack.transcript.error"
      error_key += "_#{type}" if type

      {
        type: "modal",
        title: {
          type: "plain_text",
          text: I18n.t("chat_integration.provider.slack.transcript.modal_title"),
        },
        blocks: [
          { type: "section", text: { type: "mrkdwn", text: ":warning: *#{I18n.t(error_key)}*" } },
        ],
      }
    end

    def slack_token_valid?
      params.require(:token)

      if SiteSetting.chat_integration_slack_incoming_webhook_token.blank? ||
           SiteSetting.chat_integration_slack_incoming_webhook_token != params[:token]
        raise Discourse::InvalidAccess.new
      end
    end

    def slack_payload_token_valid?
      params.require(:payload)

      json = JSON.parse(params[:payload], symbolize_names: true)

      if SiteSetting.chat_integration_slack_incoming_webhook_token.blank? ||
           SiteSetting.chat_integration_slack_incoming_webhook_token != json[:token]
        raise Discourse::InvalidAccess.new
      end
    end
  end

  class SlackEngine < ::Rails::Engine
    engine_name DiscourseChatIntegration::PLUGIN_NAME + "-slack"
    isolate_namespace DiscourseChatIntegration::Provider::SlackProvider
  end

  SlackEngine.routes.draw do
    post "command" => "slack_command#command"
    post "interactive" => "slack_command#interactive"
  end
end
