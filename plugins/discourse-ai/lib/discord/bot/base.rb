# frozen_string_literal: true

module DiscourseAi
  module Discord::Bot
    class Base
      def initialize(body)
        @interaction = JSON.parse(body, object_class: OpenStruct)
        @query = @interaction.data.options.first.value
        @token = @interaction.token
      end

      def handle_interaction!
        raise NotImplementedError
      end

      def create_reply(reply)
        api_endpoint = "https://discord.com/api/webhooks/#{SiteSetting.ai_discord_app_id}/#{@token}"
        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response =
          conn.post(
            api_endpoint,
            { content: reply }.to_json,
            { "Content-Type" => "application/json" },
          )
        @reply_response = JSON.parse(response.body, symbolize_names: true)
      end

      def update_reply(reply)
        api_endpoint =
          "https://discord.com/api/webhooks/#{SiteSetting.ai_discord_app_id}/#{@token}/messages/@original"
        conn = Faraday.new { |f| f.adapter FinalDestination::FaradayAdapter }
        response =
          conn.patch(
            api_endpoint,
            { content: reply }.to_json,
            { "Content-Type" => "application/json" },
          )
        @last_update_response = JSON.parse(response.body, symbolize_names: true)
      end
    end
  end
end
