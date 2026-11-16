# frozen_string_literal: true

module Live
  class AgentsController < ApplicationController
    def index
      unless guardian.can_invite_live_agents? && Live::AgentBot.available?
        raise Discourse::InvalidAccess
      end

      refresh = params[:refresh].to_s == "true"
      RateLimiter.new(current_user, "live-agent-list-refresh", 6, 1.minute).performed! if refresh

      result = Live::Livekit::CloudAgentClient.list(refresh:)
      if result[:ok]
        render json: { agents: result[:agents] }
      else
        render_json_error(I18n.t("live.errors.agent_list_failed"), status: 503)
      end
    end
  end
end
