# frozen_string_literal: true

class Users::AssociateAccountsController < ApplicationController
  REDIS_PREFIX ||= "omniauth_reconnect"

  ##
  # Presents a confirmation screen to the user. Accessed via GET, with no CSRF checks
  def connect_info
    auth = get_auth_hash

    provider_name = auth.provider
    authenticator = Discourse.enabled_authenticators.find { |a| a.name == provider_name }
    raise Discourse::InvalidAccess.new(I18n.t('authenticator_not_found')) if authenticator.nil?

    account_description = authenticator.description_for_auth_hash(auth)

    render json: { token: params[:token], provider_name: provider_name, account_description: account_description }
  end

  ##
  # Presents a confirmation screen to the user. Accessed via GET, with no CSRF checks
  def connect
    auth = get_auth_hash
    Discourse.redis.del "#{REDIS_PREFIX}_#{current_user&.id}_#{params[:token]}"

    provider_name = auth.provider
    authenticator = Discourse.enabled_authenticators.find { |a| a.name == provider_name }
    raise Discourse::InvalidAccess.new(I18n.t('authenticator_not_found')) if authenticator.nil?

    auth_result = authenticator.after_authenticate(auth, existing_account: current_user)
    DiscourseEvent.trigger(:after_auth, authenticator, auth_result)

    render json: success_json
  end

  private

  def get_auth_hash
    token = params[:token]
    json = Discourse.redis.get "#{REDIS_PREFIX}_#{current_user&.id}_#{token}"
    raise Discourse::NotFound if json.nil?

    OmniAuth::AuthHash.new(JSON.parse(json))
  end
end
