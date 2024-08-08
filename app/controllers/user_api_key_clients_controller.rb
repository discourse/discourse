# frozen_string_literal: true
class UserApiKeyClientsController < ApplicationController
  layout "no_ember"

  requires_login
  skip_before_action :check_xhr, :preload_json

  def register
    require_params

    client = UserApiKeyClient.find_or_initialize_by(client_id: params[:client_id])
    client.application_name = params[:application_name]
    client.public_key = params[:public_key]
    client.auth_redirect = params[:auth_redirect]

    if client.save!
      render json: success_json
    else
      render json: failed_json
    end
  end

  def require_params
    %i[client_id application_name public_key auth_redirect].each { |p| params.require(p) }
    OpenSSL::PKey::RSA.new(params[:public_key])
  end
end
