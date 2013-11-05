require_dependency 'discourse_hub'
require_dependency 'user_name_suggester'
require_dependency 'user_activator'

class UsersController < ApplicationController

  skip_before_filter :authorize_mini_profiler, only: [:avatar]
  skip_before_filter :check_xhr, only: [:show, :password_reset, :update, :activate_account, :authorize_email, :user_preferences_redirect, :avatar]

  before_filter :ensure_logged_in, only: [:username, :update, :change_email, :user_preferences_redirect, :upload_avatar, :toggle_avatar]

  # we need to allow account creation with bad CSRF tokens, if people are caching, the CSRF token on the
  #  page is going to be empty, this means that server will see an invalid CSRF and blow the session
  #  once that happens you can't log in with social
  skip_before_filter :verify_authenticity_token, only: [:create]
  skip_before_filter :redirect_to_login_if_required, only: [:check_username,
                                                            :create,
                                                            :get_honeypot_value,
                                                            :activate_account,
                                                            :send_activation_email,
                                                            :authorize_email,
                                                            :password_reset]

  def show
    @user = fetch_user_from_params
    user_serializer = UserSerializer.new(@user, scope: guardian, root: 'user')
    respond_to do |format|
      format.html do
        store_preloaded("user_#{@user.username}", MultiJson.dump(user_serializer))
      end

      format.json do
        render_json_dump(user_serializer)
      end
    end
  end

  def user_preferences_redirect
    redirect_to email_preferences_path(current_user.username_lower)
  end

  def update
    user = User.where(username_lower: params[:username].downcase).first
    guardian.ensure_can_edit!(user)
    json_result(user, serializer: UserSerializer) do |u|

      website = params[:website]
      if website
        website = "http://" + website unless website =~ /^http/
      end

      u.bio_raw = params[:bio_raw] || u.bio_raw
      u.name = params[:name] || u.name
      u.website = website || u.website
      u.digest_after_days = params[:digest_after_days] || u.digest_after_days
      u.auto_track_topics_after_msecs = params[:auto_track_topics_after_msecs].to_i if params[:auto_track_topics_after_msecs]
      u.new_topic_duration_minutes = params[:new_topic_duration_minutes].to_i if params[:new_topic_duration_minutes]
      u.title = params[:title] || u.title if guardian.can_grant_title?(u)

      [:email_digests, :email_always, :email_direct, :email_private_messages,
       :external_links_in_new_tab, :enable_quoting, :dynamic_favicon].each do |i|
        if params[i].present?
          u.send("#{i.to_s}=", params[i] == 'true')
        end
      end

      u.save ? u : nil
    end
  end

  def username
    params.require(:new_username)

    user = fetch_user_from_params
    guardian.ensure_can_edit_username!(user)

    result = user.change_username(params[:new_username])
    raise Discourse::InvalidParameters.new(:new_username) unless result

    render nothing: true
  end

  def preferences
    render nothing: true
  end

  def invited
    params.require(:username)
    params.permit(:filter)

    by_user = fetch_user_from_params

    invited = Invite.where(invited_by_id: by_user.id)
                    .includes(:user => :user_stat)
                    .order('CASE WHEN invites.user_id IS NOT NULL THEN 0 ELSE 1 END',
                           'user_stats.time_read DESC',
                           'invites.redeemed_at DESC')
                    .limit(SiteSetting.invites_shown)
                    .references('user_stats')

    unless guardian.can_see_pending_invites_from?(by_user)
      invited = invited.where('invites.user_id IS NOT NULL')
    end

    if params[:filter].present?
      invited = invited.where('(LOWER(invites.email) LIKE :filter) or (LOWER(users.username) LIKE :filter)', filter: "%#{params[:filter].downcase}%")
                       .references(:users)
    end

    render_serialized(invited.to_a, InviteSerializer)
  end

  def is_local_username
    params.require(:username)
    u = params[:username].downcase
    r = User.exec_sql('select 1 from users where username_lower = ?', u).values
    render json: {valid: r.length == 1}
  end

  def render_available_true
    render(json: { available: true })
  end

  def changing_case_of_own_username(target_user, username)
    target_user and username.downcase == target_user.username.downcase
  end

  # Used for checking availability of a username and will return suggestions
  # if the username is not available.
  def check_username
    params.require(:username)
    username = params[:username]

    target_user = user_from_params_or_current_user

    # The special case where someone is changing the case of their own username
    return render_available_true if changing_case_of_own_username(target_user, username)

    checker = UsernameCheckerService.new
    email = params[:email] || target_user.try(:email)
    render(json: checker.check_username(username, email))
  rescue RestClient::Forbidden
    render json: {errors: [I18n.t("discourse_hub.access_token_problem")]}
  end

  def user_from_params_or_current_user
    params[:for_user_id] ? User.find(params[:for_user_id]) : current_user
  end


  def create
    return fake_success_response if suspicious? params

    user = User.new_from_params(params)
    user.ip_address = request.ip
    auth = authenticate_user(user, params)
    register_nickname(user)

    user.save ? user_create_successful(user, auth) : user_create_failed(user)

  rescue ActiveRecord::StatementInvalid
    render json: { success: false, message: I18n.t("login.something_already_taken") }
  rescue DiscourseHub::NicknameUnavailable => e
    render json: e.response_message
  rescue RestClient::Forbidden
    render json: { errors: [I18n.t("discourse_hub.access_token_problem")] }
  end

  def get_honeypot_value
    render json: {value: honeypot_value, challenge: challenge_value}
  end

  def password_reset
    expires_now()

    @user = EmailToken.confirm(params[:token])
    if @user.blank?
      flash[:error] = I18n.t('password_reset.no_token')
    else
      if request.put? && params[:password].present?
        @user.password = params[:password]
        if @user.save

          if Guardian.new(@user).can_access_forum?
            # Log in the user
            log_on_user(@user)
            flash[:success] = I18n.t('password_reset.success')
          else
            @requires_approval = true
            flash[:success] = I18n.t('password_reset.success_unapproved')
          end
        end
      end
    end
    render layout: 'no_js'
  end

  def change_email
    params.require(:email)
    user = fetch_user_from_params
    guardian.ensure_can_edit_email!(user)
    lower_email = Email.downcase(params[:email]).strip

    # Raise an error if the email is already in use
    if User.where("email = ?", lower_email).exists?
      raise Discourse::InvalidParameters.new(:email)
    end

    email_token = user.email_tokens.create(email: lower_email)
    Jobs.enqueue(
      :user_email,
      to_address: lower_email,
      type: :authorize_email,
      user_id: user.id,
      email_token: email_token.token
    )

    render nothing: true
  end

  def authorize_email
    expires_now()
    if @user = EmailToken.confirm(params[:token])
      log_on_user(@user)
    else
      flash[:error] = I18n.t('change_email.error')
    end
    render layout: 'no_js'
  end

  def activate_account
    expires_now()
    if @user = EmailToken.confirm(params[:token])

      # Log in the user unless they need to be approved
      if Guardian.new(@user).can_access_forum?
        @user.enqueue_welcome_message('welcome_user') if @user.send_welcome_message
        log_on_user(@user)
      else
        @needs_approval = true
      end

    else
      flash[:error] = I18n.t('activation.already_done')
    end
    render layout: 'no_js'
  end

  def send_activation_email
    @user = fetch_user_from_params
    @email_token = @user.email_tokens.unconfirmed.active.first
    if @user
      @email_token ||= @user.email_tokens.create(email: @user.email)
      Jobs.enqueue(:user_email, type: :signup, user_id: @user.id, email_token: @email_token.token)
    end
    render nothing: true
  end

  def search_users
    term = params[:term].to_s.strip
    topic_id = params[:topic_id]
    topic_id = topic_id.to_i if topic_id

    results = UserSearch.new(term, topic_id).search

    user_fields = [:username, :use_uploaded_avatar, :upload_avatar_template, :uploaded_avatar_id]
    user_fields << :name if SiteSetting.enable_names?

    render json: { users: results.as_json(only: user_fields, methods: :avatar_template) }
  end

  # [LEGACY] avatars in quotes/oneboxes might still be pointing to this route
  # fixing it requires a rebake of all the posts
  def avatar
    user = User.where(username_lower: params[:username].downcase).first
    if user.present?
      size = determine_avatar_size(params[:size])
      url = user.avatar_template.gsub("{size}", size.to_s)
      expires_in 1.day
      redirect_to url
    else
      raise ActiveRecord::RecordNotFound
    end
  end

  def determine_avatar_size(size)
    size = size.to_i
    size = 64 if size == 0
    size = 10 if size < 10
    size = 128 if size > 128
    size
  end

  def upload_avatar
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    file = params[:file] || params[:files].first

    # Only allow url uploading for API users
    # TODO: Does not protect from huge uploads
    # https://github.com/discourse/discourse/pull/1512
    if file.is_a?(String) && is_api?
      adapted   = ::UriAdapter.new(file)
      file      = adapted.build_uploaded_file
      filesize  = adapted.file_size
    elsif file.is_a?(String)
      return render status: 422, text: I18n.t("upload.images.unknown_image_type")
    end

    # check the file size (note: this might also be done in the web server)
    filesize ||= File.size(file.tempfile)
    max_size_kb = SiteSetting.max_image_size_kb * 1024

    if filesize > max_size_kb
      return render status: 413,
                    text: I18n.t("upload.images.too_large",
                                  max_size_kb: max_size_kb)
    end

    unless SiteSetting.authorized_image?(file)
      return render status: 422, text: I18n.t("upload.images.unknown_image_type")
    end

    upload = Upload.create_for(user.id, file, filesize)
    user.update_avatar(upload)

    Jobs.enqueue(:generate_avatars, user_id: user.id, upload_id: upload.id)

    render json: {
      url: upload.url,
      width: upload.width,
      height: upload.height,
    }

  rescue Discourse::InvalidParameters
    render status: 422, text: I18n.t("upload.images.unknown_image_type")
  rescue FastImage::ImageFetchFailure
    render status: 422, text: I18n.t("upload.images.fetch_failure")
  rescue FastImage::UnknownImageType
    render status: 422, text: I18n.t("upload.images.unknown_image_type")
  rescue FastImage::SizeNotFound
    render status: 422, text: I18n.t("upload.images.size_not_found")
  end

  def toggle_avatar
    params.require(:use_uploaded_avatar)
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    user.use_uploaded_avatar = params[:use_uploaded_avatar]
    user.save!

    render nothing: true
  end

  private

    def honeypot_value
      Digest::SHA1::hexdigest("#{Discourse.current_hostname}:#{Discourse::Application.config.secret_token}")[0,15]
    end

    def challenge_value
      challenge = $redis.get('SECRET_CHALLENGE')
      unless challenge && challenge.length == 16*2
        challenge = SecureRandom.hex(16)
        $redis.set('SECRET_CHALLENGE',challenge)
      end

      challenge
    end

    def suspicious?(params)
      honeypot_or_challenge_fails?(params) || SiteSetting.invite_only?
    end

    def fake_success_response
      render(
        json: {
          success: true,
          active: false,
          message: I18n.t("login.activate_email", email: params[:email])
        }
      )
    end

    def honeypot_or_challenge_fails?(params)
      params[:password_confirmation] != honeypot_value ||
      params[:challenge] != challenge_value.try(:reverse)
    end

    def valid_session_authentication?(auth, email)
      auth && auth[:email] == email && auth[:email_valid]
    end

    def create_third_party_auth_records(user, auth)
      return unless auth && auth[:authenticator_name]

      authenticator = Users::OmniauthCallbacksController.find_authenticator(auth[:authenticator_name])
      authenticator.after_create_account(user, auth)
    end

    def register_nickname(user)
      if user.valid? && SiteSetting.call_discourse_hub?
        DiscourseHub.register_nickname(user.username, user.email)
      end
    end

    def user_create_successful(user, auth)
      activator = UserActivator.new(user, request, session, cookies)
      create_third_party_auth_records(user, auth)

      # Clear authentication session.
      session[:authentication] = nil
      render json: { success: true, active: user.active?, message: activator.activation_message }
    end

    def user_create_failed(user)
      render json: {
        success: false,
        message: I18n.t("login.errors", errors: user.errors.full_messages.join("\n")),
        errors: user.errors.to_hash,
        values: user.attributes.slice("name", "username", "email")
      }
    end

    def authenticate_user(user, params)
      auth = session[:authentication]
      user.active = true if valid_session_authentication?(auth, params[:email])
      user.password_required! unless auth
      auth
    end

end
