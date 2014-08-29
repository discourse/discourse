# name: discourse-upcase_auth
# about: upcase.com login support for Discourse
# version: 0.2
# authors: Chad Pytel, thoughtbot

require 'auth/oauth2_authenticator'

class UpcaseAuthenticator < ::Auth::OAuth2Authenticator
  def after_authenticate(auth_token)
    auth_token[:uid] = auth_token[:uid].to_s
    result = super
    populate_result_with_auth_info(result, auth_token)
    set_permissions(result.user, result.extra_data)
    result
  end

  def after_create_account(user, auth)
    set_permissions(user, auth[:extra_data])
    super
  end

  def register_middleware(omniauth)
    omniauth.provider :upcase,
      ENV['UPCASE_OAUTH_CLIENT_ID_PRODUCTION'],
      ENV['UPCASE_OAUTH_CLIENT_SECRET_PRODUCTION']
  end

  private

  def populate_result_with_auth_info(result, auth_token)
    result.name = "#{auth_token[:info][:first_name]} #{auth_token[:info][:last_name]}"
    result.extra_data[:has_active_subscription] = auth_token[:info][:has_active_subscription]
    result.extra_data[:admin] = auth_token[:info][:admin]
  end

  def set_permissions(user, permissions)
    if user && user.persisted?
      set_admin_permission(user, permissions[:admin])
      set_subscription_permissions(user, permissions[:has_active_subscription])
    end
  end

  def set_admin_permission(user, admin)
    user.admin = admin
    user.save
  end

  def set_subscription_permissions(user, user_has_active_subscription)
    if user_has_active_subscription
      if not_in_subscriber_group?(user)
        subscriber_group.add(user)
      end
    else
      subscriber_group_user(user).try(:destroy)
    end
  end

  def not_in_subscriber_group?(user)
    subscriber_group_user(user).blank?
  end

  def subscriber_group_user(user)
    subscriber_group.group_users.where(user_id: user.id).first
  end

  def subscriber_group
    Group.lookup_group('Prime')
  end
end

require 'omniauth-oauth2'

class OmniAuth::Strategies::Upcase < OmniAuth::Strategies::OAuth2
  UPCASE_URL = ENV['UPCASE_URL']

  option :name, :upcase

  option :client_options, {
    :site => UPCASE_URL,
    :authorize_url => '/oauth/authorize'
  }

  uid { raw_info['id'] }

  info do
    raw_info.except('id')
  end

  def raw_info
    @raw_info ||= access_token.get('/api/v1/me.json').parsed
    @raw_info['user']
  end
end

auth_provider :title => 'with Upcase',
    :message => 'Log in via Upcase',
    :frame_width => 920,
    :frame_height => 800,
    :authenticator => UpcaseAuthenticator.new('upcase', trusted: true)

register_css <<CSS
.btn-social.upcase {
  background: #b22115;
}
CSS
