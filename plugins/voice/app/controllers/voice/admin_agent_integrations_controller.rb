# frozen_string_literal: true

module Voice
  class AdminAgentIntegrationsController < ::Admin::AdminController
    requires_plugin "voice"

    def index
      bots = User.where("id < 0").where.not(id: Discourse.system_user.id).order(:username)
      render json: {
               integrations: serialize_data(integrations, AgentIntegrationSerializer),
               bots: serialize_data(bots, BasicUserSerializer),
             }
    end

    def create
      integration = AgentIntegration.new(integration_params)
      integration.credential_digest = SecureRandom.hex(32)
      validate_bot!(integration)
      integration.save!
      credential = AgentManager.create_credential!(integration)
      response.headers["Cache-Control"] = "no-store"
      render json: { integration: serialize(integration), credential: credential }, status: :created
    end

    def update
      integration = integrations.find(params[:id])
      AgentIntegration.transaction do
        integration.assign_attributes(integration_params)
        raise Discourse::InvalidParameters.new(:bot_user_id) if integration.bot_user_id_changed?
        validate_bot!(integration)
        integration.save!
      end
      AgentManager.evict_integration!(integration)
      render json: { integration: serialize(integration) }
    end

    def destroy
      integration = integrations.find(params[:id])
      integration.revoke!
      AgentManager.evict_integration!(integration)
      head :no_content
    end

    def restore
      integration = integrations.find(params[:id])
      integration.restore!
      AgentManager.evict_integration!(integration)
      render json: { integration: serialize(integration) }
    end

    def restore_exclusion
      integration = integrations.find(params[:id])
      integration.exclusions.where(room_id: params[:room_id]).delete_all
      AgentManager.evict_integration!(integration)
      head :no_content
    end

    def rotate
      integration = integrations.find(params[:id])
      credential = AgentManager.create_credential!(integration)
      AgentManager.evict_integration!(integration)
      response.headers["Cache-Control"] = "no-store"
      render json: { integration: serialize(integration), credential: credential }
    end

    def invite
      integration = integrations.find(params[:id])
      room = Room.find(params.require(:room_id))
      dispatch_id =
        AgentDispatcher.dispatch!(integration:, room:, agent_name: params.require(:agent_name))
      render json: { dispatch_id: }, status: :created
    rescue AgentManager::AuthorizationError
      render_json_error(I18n.t("voice.errors.agent_dispatch_forbidden"), status: 403)
    rescue AgentDispatcher::DispatchError
      render_json_error(I18n.t("voice.errors.agent_dispatch_failed"), status: 503)
    end

    private

    def integrations
      AgentIntegration.includes(:bot_user, :integration_rooms, :exclusions).order(:name)
    end

    def serialize(integration)
      AgentIntegrationSerializer.new(integration, scope: guardian, root: false).as_json
    end

    def integration_params
      permitted = params.require(:integration).permit(:name, :bot_user_id, :role, room_ids: [])
      room_ids = Array(permitted.delete(:room_ids)).map(&:to_i).select(&:positive?).uniq
      raise Discourse::InvalidParameters.new(:room_ids) if room_ids.empty?
      unless Room.where(id: room_ids).count == room_ids.length
        raise Discourse::InvalidParameters.new(:room_ids)
      end

      role = permitted.delete(:role)
      {
        **permitted,
        role:
          AgentIntegration::ROLES.fetch(role.to_s) do
            raise Discourse::InvalidParameters.new(:role)
          end,
        rooms: Room.where(id: room_ids),
      }
    end

    def validate_bot!(integration)
      user = User.find_by(id: integration.bot_user_id)
      return if user&.bot? && user.id.negative? && !user.is_system_user?

      raise Discourse::InvalidParameters.new(:bot_user_id)
    end
  end
end
