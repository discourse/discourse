# frozen_string_literal: true

class Admin::McpClientsController < Admin::AdminController
  def index
    clients = McpOauthClient.includes(:authorizations).order(updated_at: :desc).limit(200)
    render json: { clients: clients.map { |client| serialize(client) } }
  end

  def show
    render json: { client: serialize(client) }
  end

  def create
    client =
      McpOauthClient.create!(
        client_params.merge(registration_type: "pre_registered", trust_state: "approved"),
      )
    StaffActionLogger.new(current_user).log_custom("mcp_client_created", client_id: client.id)
    render json: { client: serialize(client) }, status: :created
  end

  def block
    client.update!(trust_state: params.fetch(:blocked, true) ? "blocked" : "approved")
    if client.blocked?
      client.authorizations.active.find_each do |authorization|
        authorization.revoke!(by_user: current_user, reason: "client_blocked")
      end
    end
    StaffActionLogger.new(current_user).log_custom(
      "mcp_client_trust_updated",
      client_id: client.id,
      trust_state: client.trust_state,
    )
    render json: { client: serialize(client) }
  end

  def refresh
    raise Discourse::InvalidParameters if client.registration_type != "cimd"
    refreshed = DiscourseMcp::OAuth::ClientResolver.resolve!(client.client_id, force: true)
    render json: { client: serialize(refreshed) }
  end

  private

  def client
    @client ||= McpOauthClient.find(params[:id])
  end

  def client_params
    params.require(:client).permit(:client_id, :name, redirect_uris: [])
  end

  def serialize(value)
    client_uri = URI.parse(value.client_id) if value.client_id.start_with?("https://")
    {
      id: value.id,
      client_id: value.client_id,
      name: value.name,
      domain: client_uri&.host,
      registration_type: value.registration_type,
      trust_state: value.trust_state,
      blocked: value.blocked?,
      redirect_uris: value.redirect_uris,
      redirect_hosts: value.redirect_uris.filter_map { |uri| URI.parse(uri).host }.uniq,
      metadata_uri: value.metadata_uri,
      first_seen_at: value.created_at,
      last_seen_at: value.last_seen_at,
      authorization_count: value.authorizations.size,
    }
  end
end
