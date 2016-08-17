class UserApiKeysController < ApplicationController

  layout 'no_ember'

  skip_before_filter :redirect_to_login_if_required, only: [:new]
  skip_before_filter :check_xhr, :preload_json
  before_filter :ensure_logged_in, only: [:create, :revoke, :undo_revoke]

  AUTH_API_VERSION ||= 1

  def new

    if request.head?
      head :ok, auth_api_version: AUTH_API_VERSION
      return
    end

    require_params
    validate_params(_skip_push=true)

    unless current_user
      cookies[:destination_url] = request.fullpath
      redirect_to path('/login')
      return
    end

    @access_description = params[:access].include?("w") ? t("user_api_key.read_write") : t("user_api_key.read")
    @application_name = params[:application_name]
    @public_key = params[:public_key]
    @nonce = params[:nonce]
    @access = params[:access]
    @client_id = params[:client_id]
    @auth_redirect = params[:auth_redirect]
    @push_url = params[:push_url]

    if @access.include?("p")
      if !SiteSetting.allow_push_user_api_keys ||
         !SiteSetting.allowed_user_api_push_urls.split('|').any?{|u| params[:push_url] == u}
        @access.gsub!("p","")
        @push_url = nil
      end
    end
  end

  def create

    require_params

    unless SiteSetting.allowed_user_api_auth_redirects
                      .split('|')
                      .any?{|u| params[:auth_redirect] == u}

        raise Discourse::InvalidAccess
    end

    raise Discourse::InvalidAccess if current_user.trust_level < SiteSetting.min_trust_level_for_user_api_key

    request_read = params[:access].include? 'r'
    request_push = params[:access].include? 'p'
    request_write = params[:access].include? 'w'

    validate_params

    # destroy any old keys we had
    UserApiKey.where(user_id: current_user.id, client_id: params[:client_id]).destroy_all

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

  def revoke
    find_key.update_columns(revoked_at: Time.zone.now)
    render json: success_json
  end

  def undo_revoke
    find_key.update_columns(revoked_at: nil)
    render json: success_json
  end

  def find_key
    key = UserApiKey.find(params[:id])
    raise Discourse::InvalidAccess unless current_user.admin || key.user_id = current_user.id
    key
  end

  def require_params
    [
     :public_key,
     :nonce,
     :access,
     :client_id,
     :auth_redirect,
     :application_name
    ].each{|p| params.require(p)}
  end

  def validate_params(skip_push_check = false)
    request_read = params[:access].include? 'r'
    request_push = params[:access].include? 'p'
    request_write = params[:access].include? 'w'

    raise Discourse::InvalidAccess unless request_read || request_push
    raise Discourse::InvalidAccess if request_read && !SiteSetting.allow_read_user_api_keys
    raise Discourse::InvalidAccess if request_write && !SiteSetting.allow_write_user_api_keys

    unless skip_push_check
      raise Discourse::InvalidAccess if request_push && !SiteSetting.allow_push_user_api_keys

      if request_push && !SiteSetting.allowed_user_api_push_urls.split('|').any?{|u| params[:push_url] == u}
        raise Discourse::InvalidAccess
      end
    end

    # our pk has got to parse
    OpenSSL::PKey::RSA.new(params[:public_key])
  end

end
