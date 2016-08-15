class UserApiKeysController < ApplicationController

  skip_before_filter :redirect_to_login_if_required, only: [:new]
  skip_before_filter :check_xhr
  before_filter :ensure_logged_in, only: [:create]

  def new
  end

  def create

    [
     :public_key,
     :nonce,
     :access,
     :client_id,
     :auth_redirect,
     :application_name
    ].each{|p| params.require(p)}

    unless SiteSetting.allowed_user_api_auth_redirects
                      .split('|')
                      .any?{|u| params[:auth_redirect] == u}

        raise Discourse::InvalidAccess
    end

    raise Discourse::InvalidAccess if current_user.trust_level < SiteSetting.min_trust_level_for_user_api_key

    request_read = params[:access].include? 'r'
    request_push = params[:access].include? 'p'
    request_write = params[:access].include? 'w'

    raise Discourse::InvalidAccess unless request_read || request_push
    raise Discourse::InvalidAccess if request_read && !SiteSetting.allow_read_user_api_keys
    raise Discourse::InvalidAccess if request_write && !SiteSetting.allow_write_user_api_keys
    raise Discourse::InvalidAccess if request_push && !SiteSetting.allow_push_user_api_keys

    if request_push && !SiteSetting.allowed_user_api_push_urls.split('|').any?{|u| params[:push_url] == u}
      raise Discourse::InvalidAccess
    end

    key = UserApiKey.create!(
      application_name: params[:application_name],
      client_id: params[:client_id],
      read: request_read,
      push: request_push,
      user_id: current_user.id,
      write: request_write,
      key: SecureRandom.hex,
      push_url: request_push ? params[:push_url] : nil
    )

    # we keep the payload short so it encrypts easily with public key
    # it is often restricted to 128 chars
    payload = {
      key: key.key,
      nonce: params[:nonce],
      access: key.access
    }.to_json

    public_key = OpenSSL::PKey::RSA.new(params[:public_key])
    payload = Base64.encode64(public_key.public_encrypt(payload))

    redirect_to "#{params[:auth_redirect]}?payload=#{CGI.escape(payload)}"
  end

end
