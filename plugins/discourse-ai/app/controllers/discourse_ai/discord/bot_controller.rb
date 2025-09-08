# frozen_string_literal: true

module DiscourseAi
  module Discord
    class BotController < ::ApplicationController
      requires_plugin ::DiscourseAi::PLUGIN_NAME

      skip_before_action :verify_authenticity_token

      def interactions
        # Request signature verification
        begin
          verify_request!
        rescue Ed25519::VerifyError
          return head :unauthorized
        end

        body = request.body.read
        interaction = JSON.parse(body, object_class: OpenStruct)

        if interaction.type == 1
          # Respond to Discord PING request
          render json: { type: 1 }
        else
          if !SiteSetting.ai_discord_allowed_guilds_map.include?(interaction.guild_id)
            return head :forbidden
          end

          response = { type: 5, data: { content: "Searching..." } }
          hijack { render json: response }

          # Respond to Discord command
          Jobs.enqueue(:stream_discord_reply, interaction: body)
        end
      end

      private

      def verify_request!
        signature = request.headers["X-Signature-Ed25519"]
        timestamp = request.headers["X-Signature-Timestamp"]
        verify_key.verify([signature].pack("H*"), "#{timestamp}#{request.raw_post}")
      end

      def verify_key
        Ed25519::VerifyKey.new([SiteSetting.ai_discord_app_public_key].pack("H*")).freeze
      end
    end
  end
end
