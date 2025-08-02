# frozen_string_literal: true

class Users::AssociateAccountsController < ApplicationController
  SECURE_SESSION_PREFIX = "omniauth_reconnect"

  before_action :ensure_logged_in

  def connect_info
    account_description = authenticator.description_for_auth_hash(auth_hash)
    existing_account_description = authenticator.description_for_user(current_user).presence
    render json: {
             token: params[:token],
             provider_name: auth_hash.provider,
             account_description: account_description,
             existing_account_description: existing_account_description,
           }
  end

  def connect
    if authenticator.description_for_user(current_user).present? && authenticator.can_revoke?
      authenticator.revoke(current_user)
    end

    DiscourseEvent.trigger(:before_auth, authenticator, auth_hash, session, cookies, request)
    auth_result = authenticator.after_authenticate(auth_hash, existing_account: current_user)
    DiscourseEvent.trigger(:after_auth, authenticator, auth_result, session, cookies, request)

    secure_session[self.class.key(params[:token])] = nil

    render json: success_json
  end

  private

  def auth_hash
    @auth_hash ||=
      begin
        token = params[:token]
        json = secure_session[self.class.key(token)]
        raise Discourse::NotFound if json.nil?

        OmniAuth::AuthHash.new(JSON.parse(json))
      end
  end

  def authenticator
    provider_name = auth_hash.provider
    authenticator = Discourse.enabled_authenticators.find { |a| a.name == provider_name }
    raise Discourse::InvalidAccess.new(I18n.t("authenticator_not_found")) if authenticator.nil?
    if !authenticator.can_connect_existing_user?
      raise Discourse::InvalidAccess.new(I18n.t("authenticator_no_connect"))
    end
    authenticator
  end

  def self.key(token)
    "#{SECURE_SESSION_PREFIX}_#{token}"
  end
end
