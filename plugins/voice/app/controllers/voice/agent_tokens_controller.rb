# frozen_string_literal: true

module Voice
  class AgentTokensController < ApplicationController
    requires_plugin "voice"
    skip_before_action :ensure_logged_in,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       :redirect_to_profile_if_required,
                       :check_xhr,
                       :preload_json

    def create
      RateLimiter.new(nil, "voice-agent-token:#{request.remote_ip}", 30, 1.minute).performed!
      integration = AgentManager.authenticate(bearer_credential)
      room = Room.find_by(id: params.require(:room_id))
      raise AgentManager::AuthorizationError if room.nil?
      AgentManager.authorize!(integration:, room:)

      session_id = AgentManager.authorize_session!(integration:, room:)
      token =
        Livekit.mint_token(
          user: integration.bot_user,
          room:,
          role: AgentManager.role_for(integration, room),
          metadata: session_id,
        )
      response.headers["Cache-Control"] = "no-store"
      render json: {
               url: SiteSetting.voice_livekit_url,
               token: token,
               participant_session_id: session_id,
               identity: integration.bot_user_id,
             }
    rescue AgentManager::AuthorizationError, Discourse::InvalidParameters
      head :forbidden
    rescue Livekit::MintError
      render_json_error(I18n.t("voice.errors.livekit_unavailable"), status: 503)
    end

    private

    def bearer_credential
      request.authorization.to_s[/\ABearer ([A-Za-z0-9_-]{43})\z/i, 1]
    end
  end
end
