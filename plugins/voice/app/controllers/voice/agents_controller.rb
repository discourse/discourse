# frozen_string_literal: true

module Voice
  class AgentsController < ApplicationController
    def index
      unless guardian.can_invite_voice_agents? && Voice::AgentBot.available?
        raise Discourse::InvalidAccess
      end

      refresh = params[:refresh].to_s == "true"
      RateLimiter.new(current_user, "voice-agent-list-refresh", 6, 1.minute).performed! if refresh

      result = Voice::Livekit::CloudAgentClient.list(refresh:)
      if result[:ok]
        render json: { agents: result[:agents] }
      else
        render_json_error(I18n.t("voice.errors.agent_list_failed"), status: 503)
      end
    end
  end
end
