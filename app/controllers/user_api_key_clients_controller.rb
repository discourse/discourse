# frozen_string_literal: true
class UserApiKeyClientsController < ApplicationController
  layout "no_ember"

  requires_login only: %i[create]
  skip_before_action :redirect_to_login_if_required, :redirect_to_profile_if_required, only: %i[new]
  skip_before_action :check_xhr, :preload_json

  def new
    require_params
    validate_params

    unless current_user
      cookies[:destination_url] = request.fullpath

      if SiteSetting.enable_discourse_connect?
        redirect_to path("/session/sso")
      else
        redirect_to path("/login")
      end
      return
    end

    unless meets_tl?
      @no_trust_level = true
      return
    end

    @application_name = params[:application_name] || @client&.application_name
    @public_key = params[:public_key] || @client&.public_key
    @client_id = params[:client_id]
    @auth_redirect = params[:auth_redirect]
    @localized_scopes = params[:scopes].split(",").map { |s| I18n.t("user_api_key.scopes.#{s}") }
    @scopes = params[:scopes]
  rescue Discourse::InvalidAccess
    @generic_error = true
  end

  def create
    raise Discourse::InvalidAccess unless meets_tl?

    require_params
    validate_params

    client = UserApiKeyClient.find_or_initialize_by(client_id: params[:client_id])
    client.application_name = params[:application_name]
    client.public_key = params[:public_key]
    client.auth_redirect = params[:auth_redirect]

    ActiveRecord::Base.transaction do
      client.save!
      @scopes.each { |scope| client.scopes.create!(name: scope) }
    end

    if !client.persisted?
      render json: failed_json.merge(errors: client.errors.full_messages), status: 400
    end

    uri = URI.parse(client.auth_redirect)
    uri.query = "success=true"
    redirect_to(uri.to_s, allow_other_host: true)
  end

  protected

  def meets_tl?
    current_user.staff? || current_user.in_any_groups?(SiteSetting.user_api_key_allowed_groups_map)
  end

  def require_params
    %i[client_id application_name public_key auth_redirect scopes].each { |p| params.require(p) }
    @scopes = params[:scopes].split(",")
  end

  def validate_params
    raise Discourse::InvalidAccess unless UserApiKeyClientScope.allowed.superset?(Set.new(@scopes))
    OpenSSL::PKey::RSA.new(params[:public_key])
  end
end
