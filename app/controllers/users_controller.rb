require_dependency 'discourse_hub'

class UsersController < ApplicationController

  skip_before_filter :check_xhr, only: [:show, :password_reset, :update, :activate_account, :avatar, :authorize_email, :user_preferences_redirect]
  skip_before_filter :authorize_mini_profiler, only: [:avatar]
  skip_before_filter :check_restricted_access, only: [:avatar]

  before_filter :ensure_logged_in, only: [:username, :update, :change_email, :user_preferences_redirect]

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

      [:email_digests, :email_direct, :email_private_messages,
       :external_links_in_new_tab, :enable_quoting].each do |i|
        if params[i].present?
          u.send("#{i.to_s}=", params[i] == 'true')
        end
      end

      if u.save
        u
      else
        nil
      end
    end
  end

  def username
    requires_parameter(:new_username)

    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    result = user.change_username(params[:new_username])
    raise Discourse::InvalidParameters.new(:new_username) unless result

    render nothing: true
  end

  def preferences
    render nothing: true
  end

  def invited
    invited_list = InvitedList.new(fetch_user_from_params)
    render_serialized(invited_list, InvitedListSerializer)
  end

  def is_local_username
    requires_parameter(:username)
    u = params[:username].downcase
    r = User.exec_sql('select 1 from users where username_lower = ?', u).values
    render json: {valid: r.length == 1}
  end

  def check_username
    requires_parameter(:username)

    validator = UsernameValidator.new(params[:username])
    if !validator.valid_format?
      render json: {errors: validator.errors}
    elsif !SiteSetting.call_discourse_hub?
      if User.username_available?(params[:username])
        render json: {available: true}
      else
        render json: {available: false, suggestion: User.suggest_username(params[:username])}
      end
    else

      # Contact the Discourse Hub server
      email_given = (params[:email].present? || current_user.present?)
      available_locally = User.username_available?(params[:username])
      global_match = false
      available_globally, suggestion_from_discourse_hub = begin
        if email_given
          global_match, available, suggestion = DiscourseHub.nickname_match?( params[:username], params[:email] || current_user.email )
          [available || global_match, suggestion]
        else
          DiscourseHub.nickname_available?(params[:username])
        end
      end

      if available_globally && available_locally
        render json: {available: true, global_match: (global_match ? true : false)}
      elsif available_locally && !available_globally
        if email_given
          # Nickname and email do not match what's registered on the discourse hub.
          render json: {available: false, global_match: false, suggestion: suggestion_from_discourse_hub}
        else
          # The nickname is available locally, but is registered on the discourse hub.
          # We need an email to see if the nickname belongs to this person.
          # Don't give a suggestion until we get the email and try to match it with on the discourse hub.
          render json: {available: false}
        end
      elsif available_globally && !available_locally
        # Already registered on this site with the matching nickname and email address. Why are you signing up again?
        render json: {available: false, suggestion: User.suggest_username(params[:username])}
      else
        # Not available anywhere.
        render json: {available: false, suggestion: suggestion_from_discourse_hub}
      end

    end
  rescue RestClient::Forbidden
    render json: {errors: [I18n.t("discourse_hub.access_token_problem")]}
  end

  def create

    if honeypot_or_challenge_fails?(params)
      # Don't give any indication that we caught you in the honeypot
      honey_pot_response = {
        success: true,
        active: false,
        message: I18n.t("login.activate_email", email: params[:email])
      }
      return render(json: honey_pot_response)
    end

    user = User.new_from_params(params)

    auth = session[:authentication]
    if valid_session_authentication?(auth, params[:email])
      user.active = true
    end
    user.password_required! unless auth

    if user.valid? && SiteSetting.call_discourse_hub?
      DiscourseHub.register_nickname(user.username, user.email)
    end

    if user.save
      msg = nil
      active_user = user.active?

      if active_user
        # If the user is active (remote authorized email)
        if SiteSetting.must_approve_users?
          msg = I18n.t("login.wait_approval")
          active_user = false
        else
          log_on_user(user)
          user.enqueue_welcome_message('welcome_user')
          msg = I18n.t("login.active")
        end
      else
        msg = I18n.t("login.activate_email", email: user.email)
        Jobs.enqueue(
          :user_email, type: :signup, user_id: user.id,
          email_token: user.email_tokens.first.token
        )
      end

      # Create 3rd party auth records (Twitter, Facebook, GitHub)
      create_third_party_auth_records(user, auth) if auth.present?

      # Clear authentication session.
      session[:authentication] = nil

      # JSON result
      render json: { success: true, active: active_user, message: msg }
    else
      render json: {
        success: false,
        message: I18n.t("login.errors", errors: user.errors.full_messages.join("\n"))
      }
    end
  rescue ActiveRecord::StatementInvalid
    render json: { success: false, message: I18n.t("login.something_already_taken") }
  rescue DiscourseHub::NicknameUnavailable
    render json: { success: false,
      message: I18n.t(
        "login.errors",
        errors:I18n.t(
          "login.not_available", suggestion: User.suggest_username(params[:username])
        )
      )
    }
  rescue RestClient::Forbidden
    render json: { errors: [I18n.t("discourse_hub.access_token_problem")] }
  end

  def get_honeypot_value
    render json: {value: honeypot_value, challenge: challenge_value}
  end

  # all avatars are funneled through here
  def avatar

    # TEMP to catch all missing spots
    # raise ActiveRecord::RecordNotFound

    user = User.select(:email).where(username_lower: params[:username].downcase).first
    if user.present?
      # for now we only support gravatar in square (redirect cached for a day),
      # later we can use x-sendfile and/or a cdn to serve local
      size = determine_avatar_size(params[:size])
      url = user.avatar_template.gsub("{size}", size.to_s)
      expires_in 1.day
      redirect_to url
    else
      raise ActiveRecord::RecordNotFound
    end
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
    requires_parameter(:email)
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)
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
      @email_token = @user.email_tokens.create(email: @user.email) if @email_token.nil?
      Jobs.enqueue(:user_email, type: :signup, user_id: @user.id, email_token: @email_token.token)
    end
    render nothing: true
  end

  def search_users
    term = params[:term].to_s.strip
    topic_id = params[:topic_id]
    topic_id = topic_id.to_i if topic_id

    results = UserSearch.search term, topic_id

    render json: { users: results.as_json(only: [ :username, :name ],
                                          methods: :avatar_template) }
  end

  private

    def honeypot_value
      Digest::SHA1::hexdigest("#{Discourse.current_hostname}:#{Discourse::Application.config.secret_token}")[0,15]
    end

    def challenge_value
      '3019774c067cc2b'
    end

    def fetch_user_from_params
      username_lower = params[:username].downcase
      username_lower.gsub!(/\.json$/, '')

      user = User.where(username_lower: username_lower).first
      raise Discourse::NotFound.new if user.blank?

      guardian.ensure_can_see!(user)
      user
    end

    def honeypot_or_challenge_fails?(params)
      params[:password_confirmation] != honeypot_value ||
      params[:challenge] != challenge_value.try(:reverse)
    end

    def valid_session_authentication?(auth, email)
      auth && auth[:email] == email && auth[:email_valid]
    end

    def create_third_party_auth_records(user, auth)
      if twitter_auth?(auth)
        TwitterUserInfo.create(
          user_id: user.id,
          screen_name: auth[:twitter_screen_name],
          twitter_user_id: auth[:twitter_user_id]
        )
      end

      if facebook_auth?(auth)
        FacebookUserInfo.create!(auth[:facebook].merge(user_id: user.id))
      end

      if github_auth?(auth)
        GithubUserInfo.create(
          user_id: user.id,
          screen_name: auth[:github_screen_name],
          github_user_id: auth[:github_user_id]
        )
      end
    end

    def twitter_auth?(auth)
      auth[:twitter_user_id] && auth[:twitter_screen_name] &&
      TwitterUserInfo.find_by_twitter_user_id(auth[:twitter_user_id]).nil?
    end

    def facebook_auth?(auth)
      auth[:facebook].present? &&
      FacebookUserInfo.find_by_facebook_user_id(auth[:facebook][:facebook_user_id]).nil?
    end

    def github_auth?(auth)
      auth[:github_user_id] && auth[:github_screen_name] &&
      GithubUserInfo.find_by_github_user_id(auth[:github_user_id]).nil?
    end

    def determine_avatar_size(size)
      size = size.to_i
      size = 64 if size == 0
      size = 10 if size < 10
      size = 128 if size > 128
      size
    end
end
