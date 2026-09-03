# frozen_string_literal: true

class Users::AssociateAccountsController < ApplicationController
  SERVER_SESSION_PREFIX = "omniauth_reconnect"

  before_action :ensure_logged_in, unless: :secure_link_landing?
  skip_before_action :check_xhr, only: :connect_info

  def connect_info
    if secure_link_landing?
      raise Discourse::NotFound if request.format.json?

      secure_link_flow.clear(:associate_account)
      token = params[:token]
      secure_link_flow.stage(:associate_account, token) if server_session[self.class.key(token)]
      return finish_secure_link_landing("/associate")
    end

    return render "default/empty" if request.format.html?

    account_description = authenticator.description_for_auth_hash(auth_hash)
    existing_account_description = authenticator.description_for_user(current_user).presence
    render json: {
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

    token = secure_link_flow.credential(:associate_account)
    server_session.delete(self.class.key(token))
    secure_link_flow.clear(:associate_account)

    render json: success_json
  end

  private

  def auth_hash
    @auth_hash ||=
      begin
        token = secure_link_flow.credential(:associate_account)
        json = server_session[self.class.key(token)]
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

  def secure_link_landing?
    params[:token].present?
  end

  def self.key(token)
    "#{SERVER_SESSION_PREFIX}_#{token}"
  end
end
