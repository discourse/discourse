require_dependency 'discourse_hub'
require_dependency 'user_name_suggester'
require_dependency 'rate_limiter'
require_dependency 'wizard'
require_dependency 'wizard/builder'
require_dependency 'admin_confirmation'

class UsersController < ApplicationController

  skip_before_action :authorize_mini_profiler, only: [:avatar]

  requires_login only: [
    :username, :update, :user_preferences_redirect, :upload_user_image,
    :pick_avatar, :destroy_user_image, :destroy, :check_emails, :topic_tracking_state,
    :preferences, :create_second_factor, :update_second_factor, :create_second_factor_backup
  ]

  skip_before_action :check_xhr, only: [
    :show, :badges, :password_reset, :update, :account_created,
    :activate_account, :perform_account_activation, :user_preferences_redirect, :avatar,
    :my_redirect, :toggle_anon, :admin_login, :confirm_admin, :email_login
  ]

  before_action :respond_to_suspicious_request, only: [:create]

  # we need to allow account creation with bad CSRF tokens, if people are caching, the CSRF token on the
  #  page is going to be empty, this means that server will see an invalid CSRF and blow the session
  #  once that happens you can't log in with social
  skip_before_action :verify_authenticity_token, only: [:create]
  skip_before_action :redirect_to_login_if_required, only: [:check_username,
                                                            :create,
                                                            :get_honeypot_value,
                                                            :account_created,
                                                            :activate_account,
                                                            :perform_account_activation,
                                                            :send_activation_email,
                                                            :update_activation_email,
                                                            :password_reset,
                                                            :confirm_email_token,
                                                            :email_login,
                                                            :admin_login,
                                                            :confirm_admin]

  def index
  end

  def show
    return redirect_to path('/login') if SiteSetting.hide_user_profiles_from_public && !current_user

    @user = fetch_user_from_params(
      include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts)
    )

    user_serializer = UserSerializer.new(@user, scope: guardian, root: 'user')

    # TODO remove this options from serializer
    user_serializer.omit_stats = true

    topic_id = params[:include_post_count_for].to_i
    if topic_id != 0
      user_serializer.topic_post_count = { topic_id => Post.secured(guardian).where(topic_id: topic_id, user_id: @user.id).count }
    end

    if !params[:skip_track_visit] && (@user != current_user)
      track_visit_to_user_profile
    end

    # This is a hack to get around a Rails issue where values with periods aren't handled correctly
    # when used as part of a route.
    if params[:external_id] && params[:external_id].ends_with?('.json')
      return render_json_dump(user_serializer)
    end

    respond_to do |format|
      format.html do
        @restrict_fields = guardian.restrict_user_fields?(@user)
        store_preloaded("user_#{@user.username}", MultiJson.dump(user_serializer))
        render :show
      end

      format.json do
        render_json_dump(user_serializer)
      end
    end
  end

  def badges
    raise Discourse::NotFound unless SiteSetting.enable_badges?
    show
  end

  def user_preferences_redirect
    redirect_to email_preferences_path(current_user.username_lower)
  end

  def update
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)
    attributes = user_params.merge!(custom_fields: params[:custom_fields])

    # We can't update the username via this route. Use the username route
    attributes.delete(:username)

    if params[:user_fields].present?
      attributes[:custom_fields] = {} unless params[:custom_fields].present?

      fields = UserField.all
      fields = fields.where(editable: true) unless current_user.staff?
      fields.each do |f|
        field_id = f.id.to_s
        next unless params[:user_fields].has_key?(field_id)

        val = params[:user_fields][field_id]
        val = nil if val === "false"
        val = val[0...UserField.max_length] if val

        return render_json_error(I18n.t("login.missing_user_field")) if val.blank? && f.required?
        attributes[:custom_fields]["user_field_#{f.id}"] = val
      end
    end

    json_result(user, serializer: UserSerializer, additional_errors: [:user_profile]) do |u|
      updater = UserUpdater.new(current_user, user)
      updater.update(attributes.permit!)
    end
  end

  def username
    params.require(:new_username)

    user = fetch_user_from_params
    guardian.ensure_can_edit_username!(user)

    result = UsernameChanger.change(user, params[:new_username], current_user)

    if result
      render json: { id: user.id, username: user.username }
    else
      render_json_error(user.errors.full_messages.join(','))
    end
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
      user.title = user_badge.badge.display_name
      user.user_profile.badge_granted_title = true
      user.save!
      user.user_profile.save!
    else
      user.title = ''
      user.save!
    end

    render body: nil
  end

  def preferences
    render body: nil
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
    user = fetch_user_from_params(include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts))
    summary = UserSummary.new(user, guardian)
    serializer = UserSummarySerializer.new(summary, scope: guardian)
    render_json_dump(serializer)
  end

  def invited
    inviter = fetch_user_from_params(include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts))
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
    inviter = fetch_user_from_params(include_inactive: current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts))

    pending_count = Invite.find_pending_invites_count(inviter)
    redeemed_count = Invite.find_redeemed_invites_count(inviter)

    render json: { counts: { pending: pending_count, redeemed: redeemed_count,
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
          .map do |name, user_count|
          {
            name: name,
            user_count: user_count
          }
        end
      end

    usernames -= groups
    usernames.each(&:downcase!)

    # Create a New Topic Scenario is not supported (per conversation with codinghorror)
    # https://meta.discourse.org/t/taking-another-1-7-release-task/51986/7
    cannot_see = []
    topic_id = params[:topic_id]
    unless topic_id.blank?
      topic = Topic.find_by(id: topic_id)
      usernames.each { |username| cannot_see.push(username) unless Guardian.new(User.find_by_username(username)).can_see?(topic) }
    end

    result = User.where(staged: false)
      .where(username_lower: usernames)
      .pluck(:username_lower)

    render json: {
      valid: result,
      valid_groups: groups,
      mentionable_groups: mentionable_groups,
      cannot_see: cannot_see,
      max_users_notified_per_group_mention: SiteSetting.max_users_notified_per_group_mention
    }
  end

  def render_available_true
    render(json: { available: true })
  end

  def changing_case_of_own_username(target_user, username)
    target_user && username.downcase == (target_user.username.downcase)
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
    params.require(:email)
    params.permit(:user_fields)

    unless SiteSetting.allow_new_registrations
      return fail_with("login.new_registrations_disabled")
    end

    if params[:password] && params[:password].length > User.max_password_length
      return fail_with("login.password_too_long")
    end

    if params[:email].length > 254 + 1 + 253
      return fail_with("login.email_too_long")
    end

    if User.reserved_username?(params[:username])
      return fail_with("login.reserved_username")
    end

    new_user_params = user_params
    user = User.unstage(new_user_params)
    user = User.new(new_user_params) if user.nil?

    # Handle API approval
    if user.approved
      user.approved_by_id ||= current_user.id
      user.approved_at ||= Time.zone.now
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
      return render body: nil, status: :forbidden
    end

    authentication.start

    if authentication.email_valid? && !authentication.authenticated?
      # posted email is different that the already validated one?
      return fail_with('login.incorrect_username_email_or_password')
    end

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
      session[SessionController::ACTIVATE_USER_KEY] = user.id

      render json: {
        success: true,
        active: user.active?,
        message: activation.message,
        user_id: user.id
      }
    elsif SiteSetting.hide_email_address_taken && user.errors[:primary_email]&.include?(I18n.t('errors.messages.taken'))
      session["user_created_message"] = activation.success_message

      if existing_user = User.find_by_email(user.primary_email&.email)
        Jobs.enqueue(:critical_user_email, type: :account_exists, user_id: existing_user.id)
      end

      render json: {
        success: true,
        active: user.active?,
        message: activation.success_message,
        user_id: user.id
      }
    else
      errors = user.errors.to_hash
      errors[:email] = errors.delete(:primary_email) if errors[:primary_email]

      render json: {
        success: false,
        message: I18n.t(
          'login.errors',
          errors: user.errors.full_messages.join("\n")
        ),
        errors: errors,
        values: {
          name: user.name,
          username: user.username,
          email: user.primary_email&.email
        },
        is_developer: UsernameCheckerService.is_developer?(user.email)
      }
    end
  rescue ActiveRecord::StatementInvalid
    render json: {
      success: false,
      message: I18n.t("login.something_already_taken")
    }
  end

  def get_honeypot_value
    render json: { value: honeypot_value, challenge: challenge_value }
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

    totp_enabled = @user&.totp_enabled?

    if !totp_enabled || @user.authenticate_second_factor(params[:second_factor_token], params[:second_factor_method].to_i)
      secure_session["second-factor-#{token}"] = "true"
    end

    valid_second_factor = secure_session["second-factor-#{token}"] == "true"

    if !@user
      @error = I18n.t('password_reset.no_token')
    elsif request.put?
      @invalid_password = params[:password].blank? || params[:password].length > User.max_password_length

      if !valid_second_factor
        RateLimiter.new(nil, "second-factor-min-#{request.remote_ip}", 3, 1.minute).performed!
        @user.errors.add(:user_second_factors, :invalid)
        @error = I18n.t('login.invalid_second_factor_code')
      elsif @invalid_password
        @user.errors.add(:password, :invalid)
      else
        @user.password = params[:password]
        @user.password_required!
        @user.user_auth_tokens.destroy_all
        if @user.save
          Invite.invalidate_for_email(@user.email) # invite link can't be used to log in anymore
          secure_session["password-#{token}"] = nil
          secure_session["second-factor-#{token}"] = nil
          logon_after_password_reset
        end
      end
    end

    respond_to do |format|
      format.html do
        if @error
          render layout: 'no_ember'
        else
          store_preloaded(
            "password_reset",
            MultiJson.dump(
              is_developer: UsernameCheckerService.is_developer?(@user.email),
              admin: @user.admin?,
              second_factor_required: !valid_second_factor,
              backup_enabled: @user.backup_codes_enabled?
            )
          )
        end

        return redirect_to(wizard_path) if request.put? && Wizard.user_requires_completion?(@user)
      end

      format.json do
        if request.put?
          if @error || @user&.errors&.any?
            render json: {
              success: false,
              message: @error,
              errors: @user&.errors&.to_hash,
              is_developer: UsernameCheckerService.is_developer?(@user&.email),
              admin: @user&.admin?
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
          render json: {
            is_developer: UsernameCheckerService.is_developer?(@user.email),
            admin: @user.admin?,
            second_factor_required: !valid_second_factor,
            backup_enabled: @user.backup_codes_enabled?
          }
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
    message =
      if Guardian.new(@user).can_access_forum?
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
    return redirect_to(path("/")) if current_user

    if request.put? && params[:email].present?
      RateLimiter.new(nil, "admin-login-hr-#{request.remote_ip}", 6, 1.hour).performed!
      RateLimiter.new(nil, "admin-login-min-#{request.remote_ip}", 3, 1.minute).performed!

      if user = User.with_email(params[:email]).admins.human_users.first
        email_token = user.email_tokens.create(email: user.email)
        Jobs.enqueue(:critical_user_email, type: :admin_login, user_id: user.id, email_token: email_token.token)
        @message = I18n.t("admin_login.success")
      else
        @message = I18n.t("admin_login.errors.unknown_email_address")
      end
    elsif (token = params[:token]).present?
      valid_token = EmailToken.valid_token_format?(token)

      if valid_token
        if params[:second_factor_token].present?
          RateLimiter.new(nil, "second-factor-min-#{request.remote_ip}", 3, 1.minute).performed!
        end

        email_token_user = EmailToken.confirmable(token)&.user
        totp_enabled = email_token_user&.totp_enabled?
        backup_enabled = email_token_user&.backup_codes_enabled?
        second_factor_token = params[:second_factor_token]
        second_factor_method = params[:second_factor_method].to_i
        confirm_email = false

        confirm_email =
          if totp_enabled
            @second_factor_required = true
            @backup_codes_enabled = true
            @message = I18n.t("login.second_factor_title")

            if second_factor_token.present?
              if email_token_user.authenticate_second_factor(second_factor_token, second_factor_method)
                true
              else
                @error = I18n.t("login.invalid_second_factor_code")
                false
              end
            end
          else
            true
          end

        if confirm_email
          @user = EmailToken.confirm(token)

          if @user && @user.admin?
            log_on_user(@user)
            return redirect_to path("/")
          else
            @message = I18n.t("admin_login.errors.unknown_email_address")
          end
        end
      else
        @message = I18n.t("admin_login.errors.invalid_token")
      end
    end

    render layout: false
  rescue RateLimiter::LimitExceeded
    @message = I18n.t("rate_limiter.slow_down")
    render layout: false
  end

  def email_login
    raise Discourse::NotFound if !SiteSetting.enable_local_logins_via_email
    return redirect_to path("/") if current_user

    expires_now
    params.require(:login)

    RateLimiter.new(nil, "email-login-hour-#{request.remote_ip}", 6, 1.hour).performed!
    RateLimiter.new(nil, "email-login-min-#{request.remote_ip}", 3, 1.minute).performed!
    user = User.human_users.find_by_username_or_email(params[:login])
    user_presence = user.present? && !user.staged

    if user
      RateLimiter.new(nil, "email-login-hour-#{user.id}", 6, 1.hour).performed!
      RateLimiter.new(nil, "email-login-min-#{user.id}", 3, 1.minute).performed!

      if user_presence
        email_token = user.email_tokens.create!(email: user.email)

        Jobs.enqueue(:critical_user_email,
          type: :email_login,
          user_id: user.id,
          email_token: email_token.token
        )
      end
    end

    json = success_json
    json[:user_found] = user_presence unless SiteSetting.hide_email_address_taken
    render json: json
  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
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
    if current_user.present?
      if SiteSetting.enable_sso_provider && payload = cookies.delete(:sso_payload)
        return redirect_to(session_sso_provider_url + "?" + payload)
      else
        return redirect_to("/")
      end
    end

    @custom_body_class = "static-account-created"
    @message = session['user_created_message'] || I18n.t('activation.missing_session')
    @account_created = { message: @message, show_controls: false }

    if session_user_id = session[SessionController::ACTIVATE_USER_KEY]
      if user = User.where(id: session_user_id.to_i).first
        @account_created[:username] = user.username
        @account_created[:email] = user.email
        @account_created[:show_controls] = !user.from_staged?
      end
    end

    store_preloaded("accountCreated", MultiJson.dump(@account_created))
    expires_now

    respond_to do |format|
      format.html { render "default/empty" }
      format.json { render json: success_json }
    end
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
        elsif SiteSetting.enable_sso_provider && payload = cookies.delete(:sso_payload)
          return redirect_to(session_sso_provider_url + "?" + payload)
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

    if params[:username].present?
      @user = User.find_by_username_or_email(params[:username])
      raise Discourse::InvalidAccess.new unless @user.present?
      raise Discourse::InvalidAccess.new unless @user.confirm_password?(params[:password])
    elsif user_key = session[SessionController::ACTIVATE_USER_KEY]
      @user = User.where(id: user_key.to_i).first
    end

    if @user.blank? || @user.active? || current_user.present? || @user.from_staged?
      raise Discourse::InvalidAccess.new
    end

    User.transaction do
      primary_email = @user.primary_email
      primary_email.email = params[:email]
      primary_email.skip_validate_email = false

      if primary_email.save
        @user.email_tokens.create!(email: @user.email)
        enqueue_activation_email
        render json: success_json
      else
        render_json_error(primary_email)
      end
    end
  end

  def send_activation_email
    if current_user.blank? || !current_user.staff?
      RateLimiter.new(nil, "activate-hr-#{request.remote_ip}", 30, 1.hour).performed!
      RateLimiter.new(nil, "activate-min-#{request.remote_ip}", 6, 1.minute).performed!
    end

    raise Discourse::InvalidAccess.new if SiteSetting.must_approve_users?

    if params[:username].present?
      @user = User.find_by_username_or_email(params[:username].to_s)
    end
    raise Discourse::NotFound unless @user

    if !current_user&.staff? &&
        @user.id != session[SessionController::ACTIVATE_USER_KEY]

      raise Discourse::InvalidAccess.new
    end

    session.delete(SessionController::ACTIVATE_USER_KEY)

    if @user.active && @user.email_confirmed?
      render_json_error(I18n.t('activation.activated'), status: 409)
    else
      @email_token = @user.email_tokens.unconfirmed.active.first
      enqueue_activation_email
      render body: nil
    end
  end

  def enqueue_activation_email
    @email_token ||= @user.email_tokens.create!(email: @user.email)
    Jobs.enqueue(:critical_user_email, type: :signup, user_id: @user.id, email_token: @email_token.token, to_address: @user.email)
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

    groups =
      if current_user
        if params[:include_mentionable_groups] == 'true'
          Group.mentionable(current_user)
        elsif params[:include_messageable_groups] == 'true'
          Group.messageable(current_user)
        end
      end

    include_groups = params[:include_groups] == "true"

    if include_groups || groups
      groups = Group.search_groups(term, groups: groups)
      groups = groups.where(visibility_level: Group.visibility_levels[:public]) if include_groups
      groups = groups.order('groups.name asc')

      to_render[:groups] = groups.map do |m|
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

    UserDestroyer.new(current_user).destroy(@user, delete_posts: true, context: params[:context])

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

    %W{number_of_deleted_posts number_of_flagged_posts number_of_flags_given number_of_suspensions warnings_received_count}.each do |info|
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

  def create_second_factor
    raise Discourse::NotFound if SiteSetting.enable_sso || !SiteSetting.enable_local_logins
    RateLimiter.new(nil, "login-hr-#{request.remote_ip}", SiteSetting.max_logins_per_ip_per_hour, 1.hour).performed!
    RateLimiter.new(nil, "login-min-#{request.remote_ip}", SiteSetting.max_logins_per_ip_per_minute, 1.minute).performed!

    unless current_user.confirm_password?(params[:password])
      return render json: failed_json.merge(
        error: I18n.t("login.incorrect_password")
      )
    end

    qrcode_svg = RQRCode::QRCode.new(current_user.totp_provisioning_uri).as_svg(
      offset: 0,
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: 4
    )

    render json: success_json.merge(
      key: current_user.user_second_factors.totp.data.scan(/.{4}/).join(" "),
      qr: qrcode_svg
    )
  end

  def create_second_factor_backup
    raise Discourse::NotFound if SiteSetting.enable_sso || !SiteSetting.enable_local_logins

    unless current_user.authenticate_totp(params[:second_factor_token])
      return render json: failed_json.merge(
        error: I18n.t("login.invalid_second_factor_code")
      )
    end

    backup_codes = current_user.generate_backup_codes

    render json: success_json.merge(
      backup_codes: backup_codes
    )
  end

  def update_second_factor
    params.require(:second_factor_token)
    params.require(:second_factor_method)

    second_factor_method = params[:second_factor_method].to_i

    [request.remote_ip, current_user.id].each do |key|
      RateLimiter.new(nil, "second-factor-min-#{key}", 3, 1.minute).performed!
    end

    if second_factor_method == UserSecondFactor.methods[:totp]
      user_second_factor = current_user.user_second_factors.totp
    elsif second_factor_method == UserSecondFactor.methods[:backup_codes]
      user_second_factor = current_user.user_second_factors.backup_codes
    end

    raise Discourse::InvalidParameters unless user_second_factor

    unless current_user.authenticate_totp(params[:second_factor_token])
      return render json: failed_json.merge(
        error: I18n.t("login.invalid_second_factor_code")
      )
    end

    if params[:enable] == "true"
      user_second_factor.update!(enabled: true)
    else
      # when disabling totp, backup is disabled too
      if second_factor_method == UserSecondFactor.methods[:totp]
        current_user.user_second_factors.destroy_all

        Jobs.enqueue(
          :critical_user_email,
          type: :account_second_factor_disabled,
          user_id: current_user.id
        )
      elsif second_factor_method == UserSecondFactor.methods[:backup_codes]
        current_user.user_second_factors.where(method: UserSecondFactor.methods[:backup_codes]).destroy_all
      end
    end

    render json: success_json
  end

  private

  def honeypot_value
    Digest::SHA1::hexdigest("#{Discourse.current_hostname}:#{GlobalSetting.safe_secret_key_base}")[0, 15]
  end

  def challenge_value
    challenge = $redis.get('SECRET_CHALLENGE')
    unless challenge && challenge.length == 16 * 2
      challenge = SecureRandom.hex(16)
      $redis.set('SECRET_CHALLENGE', challenge)
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
    permitted = [
      :name,
      :email,
      :password,
      :username,
      :title,
      :date_of_birth,
      :muted_usernames,
      :theme_key,
      :locale,
      :bio_raw,
      :location,
      :website,
      :dismissed_banner_key,
      :profile_background,
      :card_background
    ]

    permitted.concat UserUpdater::OPTION_ATTR
    permitted.concat UserUpdater::CATEGORY_IDS.keys.map { |k| { k => [] } }
    permitted.concat UserUpdater::TAG_NAMES.keys

    result = params
      .permit(permitted)
      .reverse_merge(
        ip_address: request.remote_ip,
        registration_ip_address: request.remote_ip,
        locale: user_locale
      )

    if !UsernameCheckerService.is_developer?(result['email']) &&
        is_api? &&
        current_user.present? &&
        current_user.admin?

      result.merge!(params.permit(:active, :staged, :approved))
    end

    modify_user_params(result)
  end

  # Plugins can use this to modify user parameters
  def modify_user_params(attrs)
    attrs
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
