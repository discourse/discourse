# frozen_string_literal: true
class UserApiKeyClientsController < ApplicationController
  layout "no_ember"

  skip_before_action :check_xhr, :preload_json, :verify_authenticity_token

  def show
    params.require(:client_id)
    client = UserApiKeyClient.find_by(client_id: params[:client_id])
    raise Discourse::InvalidParameters unless client && client.auth_redirect.present?
    head :ok
  end

  def create
    rate_limit
    require_params
    validate_params
    ensure_new_client

    client = UserApiKeyClient.new(client_id: params[:client_id])
    client.application_name = params[:application_name]
    client.public_key = params[:public_key]
    client.auth_redirect = params[:auth_redirect]

    ActiveRecord::Base.transaction do
      client.save!
      @scopes.each { |scope| client.scopes.create!(name: scope) }
    end

    if client.persisted?
      render json: success_json
    else
      render json: failed_json
    end
  end

  def rate_limit
    RateLimiter.new(nil, "user-api-key-clients-#{request.remote_ip}", 1, 24.hours).performed!
  end

  def require_params
    %i[client_id application_name public_key auth_redirect scopes].each { |p| params.require(p) }
    @scopes = params[:scopes].split(",")
  end

  def validate_params
    raise Discourse::InvalidAccess unless UserApiKeyClientScope.allowed.superset?(Set.new(@scopes))
    OpenSSL::PKey::RSA.new(params[:public_key])
  end

  def ensure_new_client
    raise Discourse::InvalidAccess if UserApiKeyClient.where(client_id: params[:client_id]).exists?
  end
end
