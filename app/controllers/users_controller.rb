require_dependency 'discourse_hub'
require_dependency 'user_name_suggester'
require_dependency 'rate_limiter'
require_dependency 'wizard'
require_dependency 'wizard/builder'
require_dependency 'admin_confirmation'

class UsersController < ApplicationController

  skip_before_filter :authorize_mini_profiler, only: [:avatar]
  skip_before_filter :check_xhr, only: [:show, :password_reset, :update, :account_created, :activate_account, :perform_account_activation, :user_preferences_redirect, :avatar, :my_redirect, :toggle_anon, :admin_login, :confirm_admin]

  before_filter :ensure_logged_in, only: [:username, :update, :user_preferences_redirect, :upload_user_image,
                                          :pick_avatar, :destroy_user_image, :destroy, :check_emails, :topic_tracking_state]

  before_filter :respond_to_suspicious_request, only: [:create]

  # we need to allow account creation with bad CSRF tokens, if people are caching, the CSRF token on the
  #  page is going to be empty, this means that server will see an invalid CSRF and blow the session
  #  once that happens you can't log in with social
  skip_before_filter :verify_authenticity_token, only: [:create]
  skip_before_filter :redirect_to_login_if_required, only: [:check_username,
                                                            :create,
                                                            :get_honeypot_value,
                                                            :account_created,
                                                            :activate_account,
                                                            :perform_account_activation,
                                                            :send_activation_email,
                                                            :update_activation_email,
                                                            :password_reset,
                                                            :confirm_email_token,
                                                            :admin_login,
                                                            :confirm_admin]

  def index
  end

  def show
    raise Discourse::InvalidAccess if SiteSetting.hide_user_profiles_from_public && !current_user

    @user = fetch_user_from_params(
      { include_inactive: current_user.try(:staff?) },
      [{ user_profile: :card_image_badge }]
    )

    user_serializer = UserSerializer.new(@user, scope: guardian, root: 'user')

    # TODO remove this options from serializer
    user_serializer.omit_stats = true

    topic_id = params[:include_post_count_for].to_i
    if topic_id != 0
      user_serializer.topic_post_count = {topic_id => Post.where(topic_id: topic_id, user_id: @user.id).count }
    end

    if !params[:skip_track_visit] && (@user != current_user)
      track_visit_to_user_profile
    end

    # This is a hack to get around a Rails issue where values with periods aren't handled correctly
    # when used as part of a route.
    if params[:external_id] and params[:external_id].ends_with? '.json'
      return render_json_dump(user_serializer)
    end

    respond_to do |format|
      format.html do
        @restrict_fields = guardian.restrict_user_fields?(@user)
        store_preloaded("user_#{@user.username}", MultiJson.dump(user_serializer))
      end

      format.json do
        render_json_dump(user_serializer)
      end
    end
  end

  def card_badge
  end

  def update_card_badge
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    user_badge = UserBadge.find_by(id: params[:user_badge_id].to_i)
    if user_badge && user_badge.user == user && user_badge.badge.image.present?
      user.user_profile.update_column(:card_image_badge_id, user_badge.badge.id)
    else
      user.user_profile.update_column(:card_image_badge_id, nil)
    end

    render nothing: true
  end

  def user_preferences_redirect
    redirect_to email_preferences_path(current_user.username_lower)
  end

  def update
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    if params[:user_fields].present?
      params[:custom_fields] = {} unless params[:custom_fields].present?

      fields = UserField.all
      fields = fields.where(editable: true) unless current_user.staff?
      fields.each do |f|
        val = params[:user_fields][f.id.to_s]
        val = nil if val === "false"
        val = val[0...UserField.max_length] if val

        return render_json_error(I18n.t("login.missing_user_field")) if val.blank? && f.required?
        params[:custom_fields]["user_field_#{f.id}"] = val
      end
    end

    json_result(user, serializer: UserSerializer, additional_errors: [:user_profile]) do |u|
      updater = UserUpdater.new(current_user, user)
      updater.update(params)
    end
  end

  def username
    params.require(:new_username)

    user = fetch_user_from_params
    guardian.ensure_can_edit_username!(user)

    # TODO proper error surfacing (result is a Model#save call)
    result = UsernameChanger.change(user, params[:new_username], current_user)
    raise Discourse::InvalidParameters.new(:new_username) unless result

    render json: {
      id: user.id,
      username: user.username
    }
  end

  def check_emails
    user = fetch_user_from_params(include_inactive: true)
    guardian.ensure_can_check_emails!(user)

    StaffActionLogger.new(current_user).log_check_email(user, context: params[:context])

    render json: {
      email: user.email,
      associated_accounts: user.associated_accounts
    }
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def topic_tracking_state
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    report = TopicTrackingState.report(user)
    serializer = ActiveModel::ArraySerializer.new(report, each_serializer: TopicTrackingStateSerializer)

    render json: MultiJson.dump(serializer)
  end

  def badge_title
    params.require(:user_badge_id)

    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    user_badge = UserBadge.find_by(id: params[:user_badge_id])
    if user_badge && user_badge.user == user && user_badge.badge.allow_title?
      user.title = user_badge.badge.name
      user.user_profile.badge_granted_title = true
      user.save!
      user.user_profile.save!
    else
      user.title = ''
      user.save!
    end

    render nothing: true
  end

  def preferences
    render nothing: true
  end

  def my_redirect
    raise Discourse::NotFound if params[:path] !~ /^[a-z_\-\/]+$/

    if current_user.blank?
      cookies[:destination_url] = "/my/#{params[:path]}"
      redirect_to "/login-preferences"
    else
      redirect_to(path("/u/#{current_user.username}/#{params[:path]}"))
    end
  end

  def summary
    user = fetch_user_from_params
    summary = UserSummary.new(user, guardian)
    serializer = UserSummarySerializer.new(summary, scope: guardian)
    render_json_dump(serializer)
  end

  def invited
    inviter = fetch_user_from_params
    offset = params[:offset].to_i || 0
    filter_by = params[:filter]

    invites = if guardian.can_see_invite_details?(inviter) && filter_by == "pending"
      Invite.find_pending_invites_from(inviter, offset)
    else
      Invite.find_redeemed_invites_from(inviter, offset)
    end

    invites = invites.filter_by(params[:search])
    render_json_dump invites: serialize_data(invites.to_a, InviteSerializer),
                     can_see_invite_details: guardian.can_see_invite_details?(inviter)
  end

  def invited_count
    inviter = fetch_user_from_params

    pending_count = Invite.find_pending_invites_count(inviter)
    redeemed_count = Invite.find_redeemed_invites_count(inviter)

    render json: {counts: { pending: pending_count, redeemed: redeemed_count,
                            total: (pending_count.to_i + redeemed_count.to_i) } }
  end

  def is_local_username
    usernames = params[:usernames]
    usernames = [params[:username]] if usernames.blank?

    groups = Group.where(name: usernames).pluck(:name)
    mentionable_groups =
      if current_user
        Group.mentionable(current_user)
          .where(name: usernames)
          .pluck(:name, :user_count)
          .map{ |name,user_count| {name: name, user_count: user_count} }
      end

    usernames -= groups
    usernames.each(&:downcase!)

    # Create a New Topic Scenario is not supported (per conversation with codinghorror)
    # https://meta.discourse.org/t/taking-another-1-7-release-task/51986/7
    cannot_see = []
    topic_id = params[:topic_id]
    unless topic_id.blank?
      topic = Topic.find_by(id: topic_id)
      usernames.each{ |username| cannot_see.push(username) unless Guardian.new(User.find_by_username(username)).can_see?(topic) }
    end

    result = User.where(staged: false)
                 .where(username_lower: usernames)
                 .pluck(:username_lower)

    render json: {valid: result, valid_groups: groups, mentionable_groups: mentionable_groups, cannot_see: cannot_see}
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
    if !params[:username].present?
      params.require(:username) if !params[:email].present?
      return render(json: success_json)
    end
    username = params[:username]

    target_user = user_from_params_or_current_user

    # The special case where someone is changing the case of their own username
    return render_available_true if changing_case_of_own_username(target_user, username)

    checker = UsernameCheckerService.new
    email = params[:email] || target_user.try(:email)
    render json: checker.check_username(username, email)
  end

  def user_from_params_or_current_user
    params[:for_user_id] ? User.find(params[:for_user_id]) : current_user
  end

  def create
    params.permit(:user_fields)

    unless SiteSetting.allow_new_registrations
      return fail_with("login.new_registrations_disabled")
    end

    if params[:password] && params[:password].length > User.max_password_length
      return fail_with("login.password_too_long")
    end

    if params[:email] && params[:email].length > 254 + 1 + 253
      return fail_with("login.email_too_long")
    end

    if User.reserved_username?(params[:username])
      return fail_with("login.reserved_username")
    end

    if user = User.where(staged: true).find_by(email: params[:email].strip.downcase)
      user_params.each { |k, v| user.send("#{k}=", v) }
      user.staged = false
    else
      user = User.new(user_params)
    end

    # Handle custom fields
    user_fields = UserField.all
    if user_fields.present?
      field_params = params[:user_fields] || {}
      fields = user.custom_fields

      user_fields.each do |f|
        field_val = field_params[f.id.to_s]
        if field_val.blank?
          return fail_with("login.missing_user_field") if f.required?
        else
          fields["user_field_#{f.id}"] = field_val[0...UserField.max_length]
        end
      end

      user.custom_fields = fields
    end

    authentication = UserAuthenticator.new(user, session)

    if !authentication.has_authenticator? && !SiteSetting.enable_local_logins
      return render nothing: true, status: 500
    end

    authentication.start

    activation = UserActivator.new(user, request, session, cookies)
    activation.start

    # just assign a password if we have an authenticator and no password
    # this is the case for Twitter
    user.password = SecureRandom.hex if user.password.blank? && authentication.has_authenticator?

    if user.save
      authentication.finish
      activation.finish

      # save user email in session, to show on account-created page
      session["user_created_message"] = activation.message

      render json: {
        success: true,
        active: user.active?,
        message: activation.message,
        user_id: user.id
      }
    else
      render json: {
        success: false,
        message: I18n.t(
          'login.errors',
          errors: user.errors.full_messages.join("\n")
        ),
        errors: user.errors.to_hash,
        values: user.attributes.slice('name', 'username', 'email'),
        is_developer: UsernameCheckerService.is_developer?(user.email)
      }
    end
  rescue ActiveRecord::StatementInvalid
    render json: {
      success: false,
      message: I18n.t("login.something_already_taken")
    }
  rescue RestClient::Forbidden
    render json: { errors: [I18n.t("discourse_hub.access_token_problem")] }
  end

  def get_honeypot_value
    render json: {value: honeypot_value, challenge: challenge_value}
  end

  def password_reset
    expires_now

    token = params[:token]

    if EmailToken.valid_token_format?(token)
      @user =
        if request.put?
          EmailToken.confirm(token)
        else
          EmailToken.confirmable(token)&.user
        end

      if @user
        secure_session["password-#{token}"] = @user.id
      else
        user_id = secure_session["password-#{token}"].to_i
        @user = User.find(user_id) if user_id > 0
      end
    end

    if !@user
      @error = I18n.t('password_reset.no_token')
    elsif request.put?
      @invalid_password = params[:password].blank? || params[:password].length > User.max_password_length

      if @invalid_password
        @user.errors.add(:password, :invalid)
      else
        @user.password = params[:password]
        @user.password_required!
        @user.user_auth_tokens.destroy_all
        if @user.save
          Invite.invalidate_for_email(@user.email) # invite link can't be used to log in anymore
          secure_session["password-#{token}"] = nil
          logon_after_password_reset
        end
      end
    end

    respond_to do |format|
      format.html do
        if @error
          render layout: 'no_ember'
        else
          store_preloaded("password_reset", MultiJson.dump({ is_developer: UsernameCheckerService.is_developer?(@user.email) }))
        end
        return redirect_to(wizard_path) if Wizard.user_requires_completion?(@user)
      end

      format.json do
        if request.put?
          if @error || @user&.errors&.any?
            render json: {
              success: false,
              message: @error,
              errors: @user&.errors.to_hash,
              is_developer: UsernameCheckerService.is_developer?(@user.email)
            }
          else
            render json: {
              success: true,
              message: @success,
              requires_approval: !Guardian.new(@user).can_access_forum?,
              redirect_to: Wizard.user_requires_completion?(@user) ? wizard_path : nil
            }
          end
        else
          render json: {is_developer: UsernameCheckerService.is_developer?(@user.email)}
        end
      end
    end
  end

  def confirm_email_token
    expires_now
    EmailToken.confirm(params[:token])
    render json: success_json
  end

  def logon_after_password_reset
    message = if Guardian.new(@user).can_access_forum?
                # Log in the user
                log_on_user(@user)
                'password_reset.success'
              else
                @requires_approval = true
                'password_reset.success_unapproved'
              end

    @success = I18n.t(message)
  end

  def admin_login
    if current_user
      return redirect_to path("/")
    end

    if request.put?
      RateLimiter.new(nil, "admin-login-hr-#{request.remote_ip}", 6, 1.hour).performed!
      RateLimiter.new(nil, "admin-login-min-#{request.remote_ip}", 3, 1.minute).performed!

      user = User.where(email: params[:email], admin: true).human_users.first
      if user
        email_token = user.email_tokens.create(email: user.email)
        Jobs.enqueue(:critical_user_email, type: :admin_login, user_id: user.id, email_token: email_token.token)
        @message = I18n.t("admin_login.success")
      else
        @message = I18n.t("admin_login.error")
      end
    elsif params[:token].present?
      # token recieved, try to login
      if EmailToken.valid_token_format?(params[:token])
        @user = EmailToken.confirm(params[:token])
        if @user && @user.admin?
          # Log in user
          log_on_user(@user)
          return redirect_to path("/")
        else
          @message = I18n.t("admin_login.error")
        end
      else
        @message = I18n.t("admin_login.error")
      end
    end

    render layout: false
  rescue RateLimiter::LimitExceeded
    @message = I18n.t("rate_limiter.slow_down")
    render layout: false
  end

  def toggle_anon
    user = AnonymousShadowCreator.get_master(current_user) ||
           AnonymousShadowCreator.get(current_user)

    if user
      log_on_user(user)
      render json: success_json
    else
      render json: failed_json, status: 403
    end
  end

  def account_created
    @custom_body_class = "static-account-created"
    @message = session['user_created_message'] || I18n.t('activation.missing_session')
    expires_now
    render layout: 'no_ember'
  end

  def activate_account
    expires_now
    render layout: 'no_ember'
  end

  def perform_account_activation
    raise Discourse::InvalidAccess.new if honeypot_or_challenge_fails?(params)
    if @user = EmailToken.confirm(params[:token])

      # Log in the user unless they need to be approved
      if Guardian.new(@user).can_access_forum?
        @user.enqueue_welcome_message('welcome_user') if @user.send_welcome_message
        log_on_user(@user)

        if Wizard.user_requires_completion?(@user)
          return redirect_to(wizard_path)
        elsif destination_url = cookies[:destination_url]
          cookies[:destination_url] = nil
          return redirect_to(destination_url)
        end
      else
        @needs_approval = true
      end

    else
      flash.now[:error] = I18n.t('activation.already_done')
    end
    render layout: 'no_ember'
  end

  def update_activation_email
    RateLimiter.new(nil, "activate-edit-email-hr-#{request.remote_ip}", 5, 1.hour).performed!

    @user = User.find_by_username_or_email(params[:username])
    raise Discourse::InvalidAccess.new unless @user.present?
    raise Discourse::InvalidAccess.new if @user.active?
    raise Discourse::InvalidAccess.new if current_user.present?

    raise Discourse::InvalidAccess.new unless @user.confirm_password?(params[:password])

    User.transaction do
      @user.email = params[:email]
      if @user.save
        @user.email_tokens.create(email: @user.email)
        enqueue_activation_email
        render json: success_json
      else
        render_json_error(@user)
      end
    end
  end

  def send_activation_email
    if current_user.blank? || !current_user.staff?
      RateLimiter.new(nil, "activate-hr-#{request.remote_ip}", 30, 1.hour).performed!
      RateLimiter.new(nil, "activate-min-#{request.remote_ip}", 6, 1.minute).performed!
    end

    @user = User.find_by_username_or_email(params[:username].to_s)

    raise Discourse::NotFound unless @user

    if !current_user&.staff? &&
        @user.id != session[SessionController::ACTIVATE_USER_KEY]

      raise Discourse::InvalidAccess
    end

    session.delete(SessionController::ACTIVATE_USER_KEY)

    if @user.active && @user.email_confirmed?
      render_json_error(I18n.t('activation.activated'), status: 409)
    else
      @email_token = @user.email_tokens.unconfirmed.active.first
      enqueue_activation_email
      render nothing: true
    end
  end

  def enqueue_activation_email
    @email_token ||= @user.email_tokens.create(email: @user.email)
    Jobs.enqueue(:critical_user_email, type: :signup, user_id: @user.id, email_token: @email_token.token)
  end

  def search_users
    term = params[:term].to_s.strip
    topic_id = params[:topic_id]
    topic_id = topic_id.to_i if topic_id
    topic_allowed_users = params[:topic_allowed_users] || false

    if params[:group].present?
      @group = Group.find_by(name: params[:group])
    end


    results = UserSearch.new(term,
                             topic_id: topic_id,
                             topic_allowed_users: topic_allowed_users,
                             searching_user: current_user,
                             group: @group
                            ).search

    user_fields = [:username, :upload_avatar_template]
    user_fields << :name if SiteSetting.enable_names?

    to_render = { users: results.as_json(only: user_fields, methods: [:avatar_template]) }

    if params[:include_groups] == "true"
      to_render[:groups] = Group.search_group(term).map do |m|
        { name: m.name, full_name: m.full_name }
      end
    end

    if params[:include_mentionable_groups] == "true" && current_user
      to_render[:groups] = Group.mentionable(current_user)
                                .where("name ILIKE :term_like", term_like: "#{term}%")
                                .map do |m|
        { name: m.name, full_name: m.full_name }
      end
    end

    render json: to_render
  end

  AVATAR_TYPES_WITH_UPLOAD ||= %w{uploaded custom gravatar}

  def pick_avatar
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    type = params[:type]
    upload_id = params[:upload_id]

    if SiteSetting.sso_overrides_avatar
      return render json: failed_json, status: 422
    end

    if !SiteSetting.allow_uploaded_avatars
      if type == "uploaded" || type == "custom"
        return render json: failed_json, status: 422
      end
    end

    user.uploaded_avatar_id = upload_id

    if AVATAR_TYPES_WITH_UPLOAD.include?(type)
      # make sure the upload exists
      unless Upload.where(id: upload_id).exists?
        return render_json_error I18n.t("avatar.missing")
      end

      if type == "gravatar"
        user.user_avatar.gravatar_upload_id = upload_id
      else
        user.user_avatar.custom_upload_id = upload_id
      end
    end

    user.save!
    user.user_avatar.save!

    render json: success_json
  end

  def destroy_user_image
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    case params.require(:type)
    when "profile_background"
      user.user_profile.clear_profile_background
    when "card_background"
      user.user_profile.clear_card_background
    else
      raise Discourse::InvalidParameters.new(:type)
    end

    render json: success_json
  end

  def destroy
    @user = fetch_user_from_params
    guardian.ensure_can_delete_user!(@user)

    UserDestroyer.new(current_user).destroy(@user, { delete_posts: true, context: params[:context] })

    render json: success_json
  end

  def read_faq
    if user = current_user
      user.user_stat.read_faq = 1.second.ago
      user.user_stat.save
    end

    render json: success_json
  end

  def staff_info
    @user = fetch_user_from_params(include_inactive: true)
    guardian.ensure_can_see_staff_info!(@user)

    result = {}

    %W{number_of_deleted_posts number_of_flagged_posts number_of_flags_given number_of_suspensions number_of_warnings}.each do |info|
      result[info] = @user.send(info)
    end

    render json: result
  end

  def confirm_admin
    @confirmation = AdminConfirmation.find_by_code(params[:token])

    raise Discourse::NotFound unless @confirmation
    raise Discourse::InvalidAccess.new unless
      @confirmation.performed_by.id == (current_user&.id || @confirmation.performed_by.id)

    if request.post?
      @confirmation.email_confirmed!
      @confirmed = true
    end

    render layout: 'no_ember'
  end

  private

    def honeypot_value
      Digest::SHA1::hexdigest("#{Discourse.current_hostname}:#{GlobalSetting.safe_secret_key_base}")[0,15]
    end

    def challenge_value
      challenge = $redis.get('SECRET_CHALLENGE')
      unless challenge && challenge.length == 16*2
        challenge = SecureRandom.hex(16)
        $redis.set('SECRET_CHALLENGE',challenge)
      end

      challenge
    end

    def respond_to_suspicious_request
      if suspicious?(params)
        render json: {
          success: true,
          active: false,
          message: I18n.t("login.activate_email", email: params[:email])
        }
      end
    end

    def suspicious?(params)
      return false if current_user && is_api? && current_user.admin?
      honeypot_or_challenge_fails?(params) || SiteSetting.invite_only?
    end

    def honeypot_or_challenge_fails?(params)
      return false if is_api?
      params[:password_confirmation] != honeypot_value ||
      params[:challenge] != challenge_value.try(:reverse)
    end

    def user_params
      result = params.permit(:name, :email, :password, :username, :date_of_birth)
                     .merge(ip_address: request.remote_ip,
                            registration_ip_address: request.remote_ip,
                            locale: user_locale)

      if !UsernameCheckerService.is_developer?(result['email']) &&
          is_api? &&
          current_user.present? &&
          current_user.admin?

        result.merge!(params.permit(:active, :staged))
      end


      result
    end

    def user_locale
      I18n.locale
    end

    def fail_with(key)
      render json: { success: false, message: I18n.t(key) }
    end

    def track_visit_to_user_profile
      user_profile_id = @user.user_profile.id
      ip = request.remote_ip
      user_id = (current_user.id if current_user)

      Scheduler::Defer.later 'Track profile view visit' do
        UserProfileView.add(user_profile_id, ip, user_id)
      end
    end

end
