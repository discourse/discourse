# frozen_string_literal: true

class UsersController < ApplicationController
  skip_before_action :authorize_mini_profiler, only: [:avatar]

  requires_login only: %i[
                   username
                   update
                   upload_user_image
                   pick_avatar
                   destroy_user_image
                   destroy
                   check_emails
                   topic_tracking_state
                   preferences
                   create_second_factor_totp
                   enable_second_factor_totp
                   disable_second_factor
                   list_second_factors
                   confirm_session
                   trusted_session
                   update_second_factor
                   create_second_factor_backup
                   select_avatar
                   notification_level
                   revoke_auth_token
                   register_second_factor_security_key
                   create_second_factor_security_key
                   create_passkey
                   register_passkey
                   rename_passkey
                   delete_passkey
                   feature_topic
                   clear_featured_topic
                   bookmarks
                   invited
                   check_sso_email
                   check_sso_payload
                   recent_searches
                   reset_recent_searches
                   user_menu_bookmarks
                   user_menu_messages
                 ]

  skip_before_action :check_xhr,
                     only: %i[
                       show
                       badges
                       password_reset_show
                       password_reset_update
                       update
                       account_created
                       activate_account
                       perform_account_activation
                       avatar
                       my_redirect
                       toggle_anon
                       admin_login
                       confirm_admin
                       email_login
                       summary
                       feature_topic
                       clear_featured_topic
                       bookmarks
                       user_menu_bookmarks
                       user_menu_messages
                     ]

  before_action :check_confirmed_session,
                only: %i[
                  create_second_factor_totp
                  enable_second_factor_totp
                  disable_second_factor
                  update_second_factor
                  create_second_factor_backup
                  register_second_factor_security_key
                  create_second_factor_security_key
                  register_passkey
                  delete_passkey
                ]

  before_action :respond_to_suspicious_request, only: [:create]

  # we need to allow account creation with bad CSRF tokens, if people are caching, the CSRF token on the
  #  page is going to be empty, this means that server will see an invalid CSRF and blow the session
  #  once that happens you can't log in with social
  skip_before_action :verify_authenticity_token, only: [:create]
  skip_before_action :redirect_to_login_if_required,
                     :redirect_to_profile_if_required,
                     only: %i[
                       check_username
                       check_email
                       create
                       account_created
                       activate_account
                       perform_account_activation
                       send_activation_email
                       update_activation_email
                       password_reset_show
                       password_reset_update
                       confirm_email_token
                       email_login
                       admin_login
                       confirm_admin
                     ]
  skip_before_action :redirect_to_profile_if_required, only: %i[show staff_info update]

  before_action :add_noindex_header, only: %i[show my_redirect]

  allow_in_staff_writes_only_mode :admin_login, :email_login, :password_reset_update

  MAX_RECENT_SEARCHES = 5

  def index
  end

  def show(for_card: false)
    guardian.ensure_public_can_see_profiles!

    @user =
      fetch_user_from_params(
        include_inactive: current_user&.staff? || for_card || SiteSetting.show_inactive_accounts,
      )

    user_serializer = nil
    if !current_user&.staff? && !@user.active?
      user_serializer = InactiveUserSerializer.new(@user, scope: guardian, root: "user")
    elsif !guardian.can_see_profile?(@user)
      user_serializer = HiddenProfileSerializer.new(@user, scope: guardian, root: "user")
    else
      serializer_class = for_card ? UserCardSerializer : UserSerializer
      user_serializer = serializer_class.new(@user, scope: guardian, root: "user")

      topic_id = params[:include_post_count_for].to_i
      if topic_id != 0 && guardian.can_see?(Topic.find_by_id(topic_id))
        user_serializer.topic_post_count = {
          topic_id => Post.secured(guardian).where(topic_id: topic_id, user_id: @user.id).count,
        }
      end
    end

    track_visit_to_user_profile if !params[:skip_track_visit] && (@user != current_user)

    # This is a hack to get around a Rails issue where values with periods aren't handled correctly
    # when used as part of a route.
    if params[:external_id] && params[:external_id].ends_with?(".json")
      return render_json_dump(user_serializer)
    end

    respond_to do |format|
      format.html do
        @restrict_fields = guardian.restrict_user_fields?(@user)
        store_preloaded("user_#{@user.username}", MultiJson.dump(user_serializer))
        render :show
      end

      format.json { render_json_dump(user_serializer) }
    end
  end

  def show_card
    show(for_card: true)
  end

  # This route is not used in core, but is used by theme components (e.g. https://meta.discourse.org/t/144479)
  def cards
    guardian.ensure_public_can_see_profiles!

    user_ids = params.require(:user_ids).split(",").map(&:to_i)
    raise Discourse::InvalidParameters.new(:user_ids) if user_ids.length > 50

    users =
      User.where(id: user_ids).includes(
        :user_option,
        :user_stat,
        :default_featured_user_badges,
        :user_profile,
        :card_background_upload,
        :primary_group,
        :flair_group,
        :primary_email,
        :user_status,
      )

    users = users.filter { |u| guardian.can_see_profile?(u) }

    preload_fields =
      User.allowed_user_custom_fields(guardian) +
        UserField.all.pluck(:id).map { |fid| "#{User::USER_FIELD_PREFIX}#{fid}" }
    User.preload_custom_fields(users, preload_fields)
    User.preload_recent_time_read(users)

    render json: users, each_serializer: UserCardSerializer
  end

  def badges
    raise Discourse::NotFound unless SiteSetting.enable_badges?
    show
  end

  def update
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    # Exclude some attributes that are only for user creation because they have
    # dedicated update routes.
    attributes = user_params.except(:username, :email, :password)

    if params[:user_fields].present?
      attributes[:custom_fields] ||= {}

      fields = UserField.all
      fields = fields.where(editable: true) unless current_user.staff?
      fields.each do |field|
        field_id = field.id.to_s
        next unless params[:user_fields].has_key?(field_id)

        value = clean_custom_field_values(field)
        value = nil if value === "false"
        value = value[0...UserField.max_length] if value

        if value.blank? &&
             (
               field.for_all_users? ||
                 field.on_signup? &&
                   user.custom_fields["#{User::USER_FIELD_PREFIX}#{field_id}"].present?
             )
          return render_json_error(I18n.t("login.missing_user_field"))
        end
        attributes[:custom_fields]["#{User::USER_FIELD_PREFIX}#{field.id}"] = value
      end
    end

    if params[:external_ids].is_a?(ActionController::Parameters) && current_user&.admin? && is_api?
      attributes[:user_associated_accounts] = []

      params[:external_ids].each do |provider_name, provider_uid|
        if provider_name == "discourse_connect"
          unless SiteSetting.enable_discourse_connect
            raise Discourse::InvalidParameters.new(:external_ids)
          end

          attributes[:discourse_connect] = { external_id: provider_uid }

          next
        end

        authenticator = Discourse.enabled_authenticators.find { |a| a.name == provider_name }
        raise Discourse::InvalidParameters.new(:external_ids) if !authenticator&.is_managed?

        attributes[:user_associated_accounts] << {
          provider_name: provider_name,
          provider_uid: provider_uid,
        }
      end
    end

    json_result(
      user,
      serializer: UserSerializer,
      additional_errors: %i[user_profile user_option],
    ) do |u|
      updater = UserUpdater.new(current_user, user)
      updater.update(attributes.permit!)
    end
  end

  def username
    params.require(:new_username)

    if clashing_with_existing_route?(params[:new_username]) ||
         User.reserved_username?(params[:new_username])
      return render_json_error(I18n.t("login.reserved_username"))
    end

    user = fetch_user_from_params
    guardian.ensure_can_edit_username!(user)

    result = UsernameChanger.change(user, params[:new_username], current_user)

    if result
      render json: { id: user.id, username: user.username }
    else
      render_json_error(user.errors.full_messages.join(","))
    end
  rescue Discourse::InvalidAccess
    if current_user&.staff?
      render_json_error(I18n.t("errors.messages.auth_overrides_username"))
    else
      render json: failed_json, status: 403
    end
  end

  def check_emails
    user = fetch_user_from_params(include_inactive: true)

    unless user == current_user
      guardian.ensure_can_check_emails!(user)
      StaffActionLogger.new(current_user).log_check_email(user, context: params[:context])
    end

    email, *secondary_emails = user.emails
    unconfirmed_emails = user.unconfirmed_emails

    render json: {
             email: email,
             secondary_emails: secondary_emails,
             unconfirmed_emails: unconfirmed_emails,
             associated_accounts: user.associated_accounts,
           }
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def check_sso_email
    user = fetch_user_from_params(include_inactive: true)

    unless user == current_user
      guardian.ensure_can_check_sso_details!(user)
      StaffActionLogger.new(current_user).log_check_email(user, context: params[:context])
    end

    email = user&.single_sign_on_record&.external_email
    email = I18n.t("user.email.does_not_exist") if email.blank?

    render json: { email: email }
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def check_sso_payload
    user = fetch_user_from_params(include_inactive: true)

    guardian.ensure_can_check_sso_details!(user)
    unless user == current_user
      StaffActionLogger.new(current_user).log_check_email(user, context: params[:context])
    end

    payload = user&.single_sign_on_record&.last_payload
    payload = I18n.t("user.email.does_not_exist") if payload.blank?

    render json: { payload: payload }
  rescue Discourse::InvalidAccess
    render json: failed_json, status: 403
  end

  def update_primary_email
    return render json: failed_json, status: 410 if !SiteSetting.enable_secondary_emails

    params.require(:email)

    user = fetch_user_from_params
    guardian.ensure_can_edit_email!(user)

    old_primary = user.primary_email
    return render json: success_json if old_primary.email == params[:email]

    new_primary = user.user_emails.find_by(email: params[:email])
    if new_primary.blank?
      return(
        render json: failed_json.merge(errors: [I18n.t("change_email.doesnt_exist")]), status: 428
      )
    end

    User.transaction do
      old_primary.update!(primary: false)
      new_primary.update!(primary: true)
      DiscourseEvent.trigger(:user_updated, user)

      if current_user.staff? && current_user != user
        StaffActionLogger.new(current_user).log_update_email(user)
      else
        UserHistory.create!(action: UserHistory.actions[:update_email], acting_user_id: user.id)
      end
    end

    render json: success_json
  end

  def destroy_email
    return render json: failed_json, status: 410 if !SiteSetting.enable_secondary_emails

    params.require(:email)

    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    ActiveRecord::Base.transaction do
      if change_requests = user.email_change_requests.where(new_email: params[:email]).presence
        change_requests.destroy_all
      elsif user.user_emails.where(email: params[:email], primary: false).destroy_all.present?
        DiscourseEvent.trigger(:user_updated, user)
      else
        return render json: failed_json, status: 428
      end

      if current_user.staff? && current_user != user
        StaffActionLogger.new(current_user).log_destroy_email(user)
      else
        UserHistory.create(action: UserHistory.actions[:destroy_email], acting_user_id: user.id)
      end
    end

    render json: success_json
  end

  def topic_tracking_state
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    report = TopicTrackingState.report(user)
    serializer = TopicTrackingStateSerializer.new(report, scope: guardian, root: false)

    render json: MultiJson.dump(serializer.as_json[:data])
  end

  def private_message_topic_tracking_state
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    report = PrivateMessageTopicTrackingState.report(user)

    serializer =
      ActiveModel::ArraySerializer.new(
        report,
        each_serializer: PrivateMessageTopicTrackingStateSerializer,
        scope: guardian,
      )

    render json: MultiJson.dump(serializer)
  end

  def badge_title
    params.require(:user_badge_id)

    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    user_badge = UserBadge.find_by(id: params[:user_badge_id])
    previous_title = user.title
    if user_badge && user_badge.user == user && user_badge.badge.allow_title?
      user.title = user_badge.badge.display_name
      user.save!

      log_params = {
        details: "title matching badge id #{user_badge.badge.id}",
        previous_value: previous_title,
        new_value: user.title,
      }

      if current_user.staff? && current_user != user
        StaffActionLogger.new(current_user).log_title_change(user, log_params)
      else
        UserHistory.create!(
          log_params.merge(target_user_id: user.id, action: UserHistory.actions[:change_title]),
        )
      end
    else
      user.title = ""
      user.save!

      log_params = { previous_value: previous_title }

      if current_user.staff? && current_user != user
        StaffActionLogger.new(current_user).log_title_revoke(
          user,
          log_params.merge(
            revoke_reason: "user title was same as revoked badge name or custom badge name",
          ),
        )
      else
        UserHistory.create!(
          log_params.merge(target_user_id: user.id, action: UserHistory.actions[:revoke_title]),
        )
      end
    end

    render body: nil
  end

  def preferences
    render body: nil
  end

  def my_redirect
    raise Discourse::NotFound if params[:path] !~ %r{\A[a-z_\-/]+\z}

    if current_user.blank?
      cookies[:destination_url] = path("/my/#{params[:path]}")
      redirect_to path("/login-preferences")
    else
      redirect_to(path("/u/#{current_user.encoded_username}/#{params[:path]}"))
    end
  end

  def profile_hidden
    render nothing: true
  end

  def summary
    guardian.ensure_public_can_see_profiles!

    @user =
      fetch_user_from_params(
        include_inactive:
          current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts),
      )
    raise Discourse::NotFound unless guardian.can_see_profile?(@user)

    response.headers["X-Robots-Tag"] = "noindex"

    respond_to do |format|
      format.html do
        @restrict_fields = guardian.restrict_user_fields?(@user)
        render :show
      end
      format.json do
        summary_json =
          Discourse
            .cache
            .fetch(summary_cache_key(@user), expires_in: 1.hour) do
              summary = UserSummary.new(@user, guardian)
              serializer = UserSummarySerializer.new(summary, scope: guardian)
              MultiJson.dump(serializer)
            end
        render json: summary_json
      end
    end
  end

  def invited
    if guardian.can_invite_to_forum?
      filter = params[:filter] || "redeemed"
      inviter =
        fetch_user_from_params(
          include_inactive: current_user.staff? || SiteSetting.show_inactive_accounts,
        )

      invites =
        if filter == "pending" && guardian.can_see_invite_details?(inviter)
          Invite.includes(:topics, :groups).pending(inviter)
        elsif filter == "expired"
          Invite.expired(inviter)
        elsif filter == "redeemed"
          Invite.redeemed_users(inviter)
        else
          Invite.none
        end

      invites = invites.offset(params[:offset].to_i || 0).limit(SiteSetting.invites_per_page)

      show_emails = guardian.can_see_invite_emails?(inviter)
      if params[:search].present? && invites.present?
        filter_sql = "(LOWER(users.username) LIKE :filter)"
        filter_sql =
          "(LOWER(invites.email) LIKE :filter) or (LOWER(users.username) LIKE :filter)" if show_emails
        invites = invites.where(filter_sql, filter: "%#{params[:search].downcase}%")
      end

      pending_count = Invite.pending(inviter).reorder(nil).count.to_i
      expired_count = Invite.expired(inviter).reorder(nil).count.to_i
      redeemed_count = Invite.redeemed_users(inviter).reorder(nil).count.to_i

      render json:
               MultiJson.dump(
                 InvitedSerializer.new(
                   OpenStruct.new(
                     invite_list: invites.to_a,
                     show_emails: show_emails,
                     inviter: inviter,
                     type: filter,
                     counts: {
                       pending: pending_count,
                       expired: expired_count,
                       redeemed: redeemed_count,
                       total: pending_count + expired_count,
                     },
                   ),
                   scope: guardian,
                   root: false,
                 ),
               )
    elsif current_user&.staff?
      message =
        if SiteSetting.enable_discourse_connect
          I18n.t("invite.disabled_errors.discourse_connect_enabled")
        end

      render_invite_error(message)
    else
      render_json_error(I18n.t("invite.disabled_errors.invalid_access"))
    end
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
    username = params[:username]&.unicode_normalize

    target_user = user_from_params_or_current_user

    # The special case where someone is changing the case of their own username
    return render_available_true if changing_case_of_own_username(target_user, username)

    checker = UsernameCheckerService.new
    email = params[:email] || target_user.try(:email)
    render json: checker.check_username(username, email)
  end

  def check_email
    begin
      RateLimiter.new(nil, "check-email-#{request.remote_ip}", 10, 1.minute).performed!
    rescue RateLimiter::LimitExceeded
      return render json: success_json
    end

    email = Email.downcase((params[:email] || "").strip)

    return render json: success_json if email.blank? || SiteSetting.hide_email_address_taken?

    if !EmailAddressValidator.valid_value?(email)
      error = User.new.errors.full_message(:email, I18n.t(:"user.email.invalid"))
      return render json: failed_json.merge(errors: [error])
    end

    if !EmailValidator.allowed?(email)
      error = User.new.errors.full_message(:email, I18n.t(:"user.email.not_allowed"))
      return render json: failed_json.merge(errors: [error])
    end

    if ScreenedEmail.should_block?(email)
      error = User.new.errors.full_message(:email, I18n.t(:"user.email.blocked"))
      return render json: failed_json.merge(errors: [error])
    end

    if User.where(staged: false).find_by_email(email).present?
      error = User.new.errors.full_message(:email, I18n.t(:"errors.messages.taken"))
      return render json: failed_json.merge(errors: [error])
    end

    render json: success_json
  end

  def user_from_params_or_current_user
    params[:for_user_id] ? User.find(params[:for_user_id]) : current_user
  end

  def create
    params.require(:email)
    params.require(:username)
    params.require(:invite_code) if SiteSetting.require_invite_code
    params.permit(:user_fields)
    params.permit(:external_ids)

    if SiteSetting.enable_discourse_connect && !is_api?
      return fail_with("login.new_registrations_disabled_discourse_connect")
    end
    return fail_with("login.new_registrations_disabled") unless SiteSetting.allow_new_registrations

    if params[:password] && params[:password].length > User.max_password_length
      return fail_with("login.password_too_long")
    end

    return fail_with("login.email_too_long") if params[:email].length > 254 + 1 + 253

    if SiteSetting.require_invite_code &&
         SiteSetting.invite_code.strip.downcase != params[:invite_code].strip.downcase
      return fail_with("login.wrong_invite_code")
    end

    if clashing_with_existing_route?(params[:username]) ||
         User.reserved_username?(params[:username])
      return fail_with("login.reserved_username")
    end

    params[:locale] ||= I18n.locale unless current_user

    new_user_params = user_params.except(:timezone)

    user = User.where(staged: true).with_email(new_user_params[:email].strip.downcase).first

    if user
      user.active = false
      user.unstage!
    end

    user ||= User.new
    user.attributes = new_user_params

    # Handle API approval and
    # auto approve users based on auto_approve_email_domains setting
    if user.approved? || EmailValidator.can_auto_approve_user?(user.email)
      ReviewableUser.set_approved_fields!(user, current_user)
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
          fields["#{User::USER_FIELD_PREFIX}#{f.id}"] = field_val[0...UserField.max_length]
        end
      end

      user.custom_fields = fields
    end

    # Handle associated accounts
    associations = []
    if params[:external_ids].is_a?(ActionController::Parameters) && current_user&.admin? && is_api?
      params[:external_ids].each do |provider_name, provider_uid|
        authenticator = Discourse.enabled_authenticators.find { |a| a.name == provider_name }
        raise Discourse::InvalidParameters.new(:external_ids) if !authenticator&.is_managed?

        association =
          UserAssociatedAccount.find_or_initialize_by(
            provider_name: provider_name,
            provider_uid: provider_uid,
          )
        associations << association
      end
    end

    authentication = UserAuthenticator.new(user, session)

    if !authentication.has_authenticator? && !SiteSetting.enable_local_logins &&
         !(current_user&.admin? && is_api?)
      return render body: nil, status: :forbidden
    end

    authentication.start

    if authentication.email_valid? && !authentication.authenticated?
      # posted email is different that the already validated one?
      return fail_with("login.incorrect_username_email_or_password")
    end

    activation = UserActivator.new(user, request, session, cookies)
    activation.start

    # just assign a password if we have an authenticator and no password
    # this is the case for Twitter
    user.password = SecureRandom.hex if user.password.blank? &&
      (authentication.has_authenticator? || associations.present?)

    if user.save
      authentication.finish
      activation.finish
      associations.each { |a| a.update!(user: user) }
      user.update_timezone_if_missing(params[:timezone])

      secure_session[HONEYPOT_KEY] = nil
      secure_session[CHALLENGE_KEY] = nil

      # save user email in session, to show on account-created page
      session["user_created_message"] = activation.message
      session[SessionController::ACTIVATE_USER_KEY] = user.id

      # If the user was created as active this will
      # ensure their email is confirmed and
      # add them to the review queue if they need to be approved
      user.activate if user.active?

      render json: { success: true, active: user.active?, message: activation.message }.merge(
               SiteSetting.hide_email_address_taken ? {} : { user_id: user.id },
             )
    elsif SiteSetting.hide_email_address_taken &&
          user.errors[:primary_email]&.include?(I18n.t("errors.messages.taken"))
      session["user_created_message"] = activation.success_message

      existing_user = User.find_by_email(user.primary_email&.email)
      if !existing_user && SiteSetting.normalize_emails
        existing_user =
          UserEmail.find_by_normalized_email(user.primary_email&.normalized_email)&.user
      end
      if existing_user
        Jobs.enqueue(:critical_user_email, type: "account_exists", user_id: existing_user.id)
      end

      render json: { success: true, active: false, message: activation.success_message }
    else
      errors = user.errors.to_hash
      errors[:email] = errors.delete(:primary_email) if errors[:primary_email]

      render json: {
               success: false,
               message: I18n.t("login.errors", errors: user.errors.full_messages.join("\n")),
               errors: errors,
               values: {
                 name: user.name,
                 username: user.username,
                 email: user.primary_email&.email,
               },
               is_developer: UsernameCheckerService.is_developer?(user.email),
             }
    end
  rescue ActiveRecord::StatementInvalid
    render json: { success: false, message: I18n.t("login.something_already_taken") }
  end

  def password_reset_show
    expires_now
    token = params[:token]

    password_reset_find_user(token, committing_change: false)

    if !@error
      security_params = {
        is_developer: UsernameCheckerService.is_developer?(@user.email),
        admin: @user.admin?,
        second_factor_required: @user.totp_enabled?,
        security_key_required: @user.security_keys_enabled?,
        backup_enabled: @user.backup_codes_enabled?,
        multiple_second_factor_methods: @user.has_multiple_second_factor_methods?,
      }
    end

    respond_to do |format|
      format.html do
        return render "password_reset", layout: "no_ember" if @error

        DiscourseWebauthn.stage_challenge(@user, secure_session)
        store_preloaded(
          "password_reset",
          MultiJson.dump(
            security_params.merge(DiscourseWebauthn.allowed_credentials(@user, secure_session)),
          ),
        )

        render "password_reset"
      end

      format.json do
        return render json: { message: @error } if @error

        DiscourseWebauthn.stage_challenge(@user, secure_session)
        render json:
                 security_params.merge(DiscourseWebauthn.allowed_credentials(@user, secure_session))
      end
    end
  end

  def password_reset_update
    expires_now
    token = params[:token]
    password_reset_find_user(token, committing_change: true)

    rate_limit_second_factor!(@user)

    # no point doing anything else if we can't even find
    # a user from the token
    if @user
      raise Discourse::ReadOnly if staff_writes_only_mode? && !@user.staff?

      if !secure_session["second-factor-#{token}"]
        second_factor_authentication_result =
          @user.authenticate_second_factor(params, secure_session)
        if !second_factor_authentication_result.ok
          user_error_key =
            (
              if second_factor_authentication_result.reason == "invalid_security_key"
                :user_second_factors
              else
                :security_keys
              end
            )
          @user.errors.add(user_error_key, :invalid)
          @error = second_factor_authentication_result.error
        else
          # this must be set because the first call we authenticate e.g. TOTP, and we do
          # not want to re-authenticate on the second call to change the password as this
          # will cause a TOTP error saying the code has already been used
          secure_session["second-factor-#{token}"] = true
        end
      end

      if @invalid_password =
           params[:password].blank? || params[:password].size > User.max_password_length
        @user.errors.add(:password, :invalid)
      end

      # if we have run into no errors then the user is a-ok to
      # change the password
      if @user.errors.empty?
        @user.update_timezone_if_missing(params[:timezone]) if params[:timezone]
        @user.password = params[:password]
        @user.password_required!
        @user.user_auth_tokens.destroy_all

        if @user.save
          Invite.invalidate_for_email(@user.email) # invite link can't be used to log in anymore
          secure_session["password-#{token}"] = nil
          secure_session["second-factor-#{token}"] = nil

          if SiteSetting.delete_associated_accounts_on_password_reset
            @user.user_associated_accounts.destroy_all
          end

          UserHistory.create!(
            target_user: @user,
            acting_user: @user,
            action: UserHistory.actions[:change_password],
          )

          logon_after_password_reset
        end
      end
    end

    respond_to do |format|
      format.html do
        return render "password_reset", layout: "no_ember" if @error

        DiscourseWebauthn.stage_challenge(@user, secure_session)

        security_params = {
          is_developer: UsernameCheckerService.is_developer?(@user.email),
          admin: @user.admin?,
          second_factor_required: @user.totp_enabled?,
          security_key_required: @user.security_keys_enabled?,
          backup_enabled: @user.backup_codes_enabled?,
          multiple_second_factor_methods: @user.has_multiple_second_factor_methods?,
        }.merge(DiscourseWebauthn.allowed_credentials(@user, secure_session))

        store_preloaded("password_reset", MultiJson.dump(security_params))

        return redirect_to(wizard_path) if Wizard.user_requires_completion?(@user)

        render "password_reset"
      end

      format.json do
        if @error || @user&.errors&.any?
          render json: {
                   success: false,
                   message: @error,
                   errors: @user&.errors&.to_hash,
                   friendly_messages: @user&.errors&.full_messages,
                   is_developer: UsernameCheckerService.is_developer?(@user&.email),
                   admin: @user&.admin?,
                 }
        else
          render json: {
                   success: true,
                   message: @success,
                   requires_approval: !Guardian.new(@user).can_access_forum?,
                   redirect_to: Wizard.user_requires_completion?(@user) ? wizard_path : nil,
                 }
        end
      end
    end
  end

  def confirm_email_token
    expires_now
    EmailToken.confirm(params[:token], scope: EmailToken.scopes[:signup])
    render json: success_json
  end

  def logon_after_password_reset
    message =
      if Guardian.new(@user).can_access_forum?
        # Log in the user
        log_on_user(@user)
        "password_reset.success"
      else
        @requires_approval = true
        "password_reset.success_unapproved"
      end

    @success = I18n.t(message)
  end

  def admin_login
    return redirect_to(path("/")) if current_user

    if request.put? && params[:email].present?
      RateLimiter.new(nil, "admin-login-hr-#{request.remote_ip}", 6, 1.hour).performed!
      RateLimiter.new(nil, "admin-login-min-#{request.remote_ip}", 3, 1.minute).performed!

      if user = User.with_email(params[:email]).admins.human_users.first
        email_token =
          user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:email_login])
        token_string = email_token.token
        token_string += "?safe_mode=no_plugins,no_themes" if params["use_safe_mode"]
        Jobs.enqueue(
          :critical_user_email,
          type: "admin_login",
          user_id: user.id,
          email_token: token_string,
        )
        @message = I18n.t("admin_login.success")
      else
        @message = I18n.t("admin_login.errors.unknown_email_address")
      end
    end

    render layout: "no_ember"
  rescue RateLimiter::LimitExceeded
    @message = I18n.t("rate_limiter.slow_down")
    render layout: "no_ember"
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
        DiscourseEvent.trigger(:before_email_login, user)

        email_token =
          user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:email_login])

        Jobs.enqueue(
          :critical_user_email,
          type: "email_login",
          user_id: user.id,
          email_token: email_token.token,
        )
      end
    end

    json = success_json
    json[:hide_taken] = SiteSetting.hide_email_address_taken
    json[:user_found] = user_presence unless SiteSetting.hide_email_address_taken
    render json: json
  rescue RateLimiter::LimitExceeded
    render_json_error(I18n.t("rate_limiter.slow_down"))
  end

  def toggle_anon
    user =
      AnonymousShadowCreator.get_master(current_user) || AnonymousShadowCreator.get(current_user)

    if user
      log_on_user(user)
      render json: success_json
    else
      render json: failed_json, status: 403
    end
  end

  def account_created
    if current_user.present?
      if SiteSetting.enable_discourse_connect_provider && payload = cookies.delete(:sso_payload)
        return redirect_to(session_sso_provider_url + "?" + payload)
      elsif destination_url = cookies.delete(:destination_url)
        return redirect_to(destination_url, allow_other_host: true)
      else
        return redirect_to(path("/"))
      end
    end

    @custom_body_class = "static-account-created"
    @message = session["user_created_message"] || I18n.t("activation.missing_session")
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

    respond_to do |format|
      format.html { render "default/empty" }
      format.json { render json: success_json }
    end
  end

  def perform_account_activation
    raise Discourse::InvalidAccess.new if honeypot_or_challenge_fails?(params)

    if @user = EmailToken.confirm(params[:token], scope: EmailToken.scopes[:signup])
      # Log in the user unless they need to be approved
      if Guardian.new(@user).can_access_forum?
        @user.enqueue_welcome_message("welcome_user") if @user.send_welcome_message
        log_on_user(@user)

        # invites#perform_accept_invitation already sets destination_url, but
        # sometimes it is lost (user changes browser, uses incognito, etc)
        #
        # The code below checks if the user was invited and redirects them to
        # the topic they were originally invited to.
        destination_url = cookies.delete(:destination_url)
        if destination_url.blank?
          topic =
            Invite
              .joins(:invited_users)
              .find_by(invited_users: { user_id: @user.id })
              &.topics
              &.first

          destination_url = path(topic.relative_url) if @user.guardian.can_see?(topic)
        end

        if Wizard.user_requires_completion?(@user)
          @redirect_to = wizard_path
        elsif destination_url.present?
          @redirect_to = destination_url
        elsif SiteSetting.enable_discourse_connect_provider &&
              payload = cookies.delete(:sso_payload)
          @redirect_to = session_sso_provider_url + "?" + payload
        end
      else
        @needs_approval = true
      end
    else
      return render_json_error(I18n.t("activation.already_done"))
    end

    render json:
             success_json.merge(redirect_to: @redirect_to, needs_approval: @needs_approval || false)
  end

  def update_activation_email
    RateLimiter.new(nil, "activate-edit-email-hr-#{request.remote_ip}", 5, 1.hour).performed!

    if params[:username].present?
      RateLimiter.new(
        nil,
        "activate-edit-email-hr-username-#{params[:username]}",
        5,
        1.hour,
      ).performed!
      @user = User.find_by_username_or_email(params[:username])
      raise Discourse::InvalidAccess.new if @user.blank?
      raise Discourse::InvalidAccess.new unless @user.confirm_password?(params[:password])
    elsif user_key = session[SessionController::ACTIVATE_USER_KEY]
      RateLimiter.new(nil, "activate-edit-email-hr-user-key-#{user_key}", 5, 1.hour).performed!
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
        @email_token =
          @user.email_tokens.create!(email: @user.email, scope: EmailToken.scopes[:signup])
        EmailToken.enqueue_signup_email(@email_token, to_address: @user.email)
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

    @user = User.find_by_username_or_email(params[:username].to_s) if params[:username].present?

    raise Discourse::NotFound unless @user

    if !current_user&.staff? && @user.id != session[SessionController::ACTIVATE_USER_KEY]
      raise Discourse::InvalidAccess.new
    end

    session.delete(SessionController::ACTIVATE_USER_KEY)

    if @user.active && @user.email_confirmed?
      render_json_error(I18n.t("activation.activated"), status: 409)
    else
      @email_token =
        @user.email_tokens.create!(email: @user.email, scope: EmailToken.scopes[:signup])
      EmailToken.enqueue_signup_email(@email_token, to_address: @user.email)
      render body: nil
    end
  end

  SEARCH_USERS_LIMIT = 50

  def search_users
    # the search can specify the parameter term or usernames, term will perform the classic user search algorithm while
    # usernames will perform an exact search on the usernames passed as parameter
    term = params[:term].to_s.strip
    usernames = params[:usernames]&.split(",")&.map { |username| username.downcase.strip }

    topic_id = params[:topic_id].to_i if params[:topic_id].present?
    category_id = params[:category_id].to_i if params[:category_id].present?

    topic_allowed_users = params[:topic_allowed_users] || false

    group_names = params[:groups] || []
    group_names << params[:group] if params[:group]
    @groups = Group.where(name: group_names) if group_names.present?

    options = {
      topic_allowed_users: topic_allowed_users,
      searching_user: current_user,
      groups: @groups,
    }

    options[:include_staged_users] = !!ActiveModel::Type::Boolean.new.cast(
      params[:include_staged_users],
    )
    options[:last_seen_users] = !!ActiveModel::Type::Boolean.new.cast(params[:last_seen_users])

    if limit = fetch_limit_from_params(default: nil, max: SEARCH_USERS_LIMIT)
      options[:limit] = limit
    end

    options[:topic_id] = topic_id if topic_id
    options[:category_id] = category_id if category_id

    results =
      if usernames.blank?
        UserSearch.new(term, options).search
      else
        User.where(username_lower: usernames).includes(:user_option).limit(limit)
      end
    to_render = serialize_found_users(results)

    # blank term is only handy for in-topic search of users after @
    # we do not want group results ever if term is blank
    groups =
      if (term.present? || usernames.present?) && current_user
        if params[:include_groups] == "true"
          Group.visible_groups(current_user)
        elsif params[:include_mentionable_groups] == "true"
          Group.mentionable(current_user)
        elsif params[:include_messageable_groups] == "true"
          Group.messageable(current_user)
        end
      end

    if groups
      DiscoursePluginRegistry
        .groups_callback_for_users_search_controller_action
        .each do |param_name, block|
        groups = block.call(groups, current_user) if params[param_name.to_s]
      end

      # the plugin registry callbacks above are only evaluated when a param
      # is present matching the name of the callback. Any modifier registered using
      # register_modifier(:groups_for_users_search) will be evaluated without needing the
      # param.
      groups = DiscoursePluginRegistry.apply_modifier(:groups_for_users_search, groups)
      groups =
        if usernames.blank?
          Group.search_groups(term, groups: groups, sort: :auto)
        else
          groups.where(name: usernames).limit(limit)
        end

      to_render[:groups] = groups.map { |m| { name: m.name, full_name: m.full_name } }
    end

    render json: to_render
  end

  AVATAR_TYPES_WITH_UPLOAD = %w[uploaded custom gravatar]

  def pick_avatar
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    return render json: failed_json, status: 422 if SiteSetting.discourse_connect_overrides_avatar

    type = params[:type]

    invalid_type = type.present? && !AVATAR_TYPES_WITH_UPLOAD.include?(type) && type != "system"
    return render json: failed_json, status: 422 if invalid_type

    if type.blank? || type == "system"
      upload_id = nil
    elsif !user.in_any_groups?(SiteSetting.uploaded_avatars_allowed_groups_map) &&
          !user.is_system_user?
      return render json: failed_json, status: 422
    else
      upload_id = params[:upload_id]
      upload = Upload.find_by(id: upload_id)

      return render_json_error I18n.t("avatar.missing") if upload.nil?

      # old safeguard
      user.create_user_avatar unless user.user_avatar

      guardian.ensure_can_pick_avatar!(user.user_avatar, upload)

      if type == "gravatar"
        user.user_avatar.gravatar_upload_id = upload_id
      else
        user.user_avatar.custom_upload_id = upload_id
      end
    end

    SiteSetting.use_site_small_logo_as_system_avatar = false if user.is_system_user?

    user.uploaded_avatar_id = upload_id
    user.save!
    user.user_avatar.save!

    render json: success_json
  end

  def select_avatar
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    url = params[:url]

    return render json: failed_json, status: 422 if url.blank?

    if SiteSetting.selectable_avatars_mode == "disabled"
      return render json: failed_json, status: 422
    end

    return render json: failed_json, status: 422 if SiteSetting.selectable_avatars.blank?

    unless upload = Upload.get_from_url(url)
      return render json: failed_json, status: 422
    end

    return render json: failed_json, status: 422 if SiteSetting.selectable_avatars.exclude?(upload)

    user.uploaded_avatar_id = upload.id

    SiteSetting.use_site_small_logo_as_system_avatar = false if user.is_system_user?

    user.save!

    avatar = user.user_avatar || user.create_user_avatar
    avatar.custom_upload_id = upload.id
    avatar.save!

    render json: {
             avatar_template: user.avatar_template,
             custom_avatar_template: user.avatar_template,
             uploaded_avatar_id: upload.id,
           }
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

  def notification_level
    target_user = fetch_user_from_params
    acting_user = current_user

    # the admin should be able to change notification levels
    # on behalf of other users, so we cannot rely on current_user
    # for this case
    if params[:acting_user_id].present? && params[:acting_user_id].to_i != current_user.id
      if current_user.staff?
        acting_user = User.find(params[:acting_user_id])
      else
        @error_message = "error"
        raise Discourse::InvalidAccess
      end
    end

    if params[:notification_level] == "ignore"
      @error_message = "ignore_error"
      guardian.ensure_can_ignore_user!(target_user)
      MutedUser.where(user: acting_user, muted_user: target_user).delete_all
      ignored_user = IgnoredUser.find_by(user: acting_user, ignored_user: target_user)
      if ignored_user.present?
        ignored_user.update(expiring_at: DateTime.parse(params[:expiring_at]))
      else
        IgnoredUser.create!(
          user: acting_user,
          ignored_user: target_user,
          expiring_at: Time.parse(params[:expiring_at]),
        )
      end
    elsif params[:notification_level] == "mute"
      @error_message = "mute_error"
      guardian.ensure_can_mute_user!(target_user)
      IgnoredUser.where(user: acting_user, ignored_user: target_user).delete_all
      MutedUser.find_or_create_by!(user: acting_user, muted_user: target_user)
    elsif params[:notification_level] == "normal"
      MutedUser.where(user: acting_user, muted_user: target_user).delete_all
      IgnoredUser.where(user: acting_user, ignored_user: target_user).delete_all
    else
      return(
        render_json_error(
          I18n.t("notification_level.invalid_value", value: params[:notification_level]),
        )
      )
    end

    render json: success_json
  rescue Discourse::InvalidAccess
    render_json_error(I18n.t("notification_level.#{@error_message}"))
  end

  def read_faq
    if user = current_user
      user.user_stat.read_faq = 1.second.ago
      user.user_stat.save
    end

    render json: success_json
  end

  def recent_searches
    if !SiteSetting.log_search_queries
      return(
        render json: failed_json.merge(error: I18n.t("user_activity.no_log_search_queries")),
               status: 403
      )
    end

    query = SearchLog.where(user_id: current_user.id)

    if current_user.user_option.oldest_search_log_date
      query = query.where("created_at > ?", current_user.user_option.oldest_search_log_date)
    end

    results =
      query.group(:term).order("max(created_at) DESC").limit(MAX_RECENT_SEARCHES).pluck(:term)

    render json: success_json.merge(recent_searches: results)
  end

  def reset_recent_searches
    current_user.user_option.update!(oldest_search_log_date: 1.second.ago)
    render json: success_json
  end

  def staff_info
    @user = fetch_user_from_params(include_inactive: true)
    guardian.ensure_can_see_staff_info!(@user)

    result = {}

    %W[
      number_of_deleted_posts
      number_of_flagged_posts
      number_of_flags_given
      number_of_suspensions
      warnings_received_count
      number_of_rejected_posts
    ].each { |info| result[info] = @user.public_send(info) }

    render json: result
  end

  def confirm_admin
    @confirmation = AdminConfirmation.find_by_code(params[:token])

    raise Discourse::NotFound unless @confirmation
    unless @confirmation.performed_by.id == (current_user&.id || @confirmation.performed_by.id)
      raise Discourse::InvalidAccess.new
    end

    if request.post?
      @confirmation.email_confirmed!
      @confirmed = true
    end

    respond_to do |format|
      format.json { render json: success_json }
      format.html { render layout: "no_ember" }
    end
  end

  def confirm_session
    if SiteSetting.enable_discourse_connect || !SiteSetting.enable_local_logins
      raise Discourse::NotFound
    end

    if confirm_secure_session
      render json: success_json
    else
      render json: failed_json.merge(error: I18n.t("login.incorrect_password_or_passkey"))
    end
  rescue ::DiscourseWebauthn::SecurityKeyError => err
    render_json_error(err.message, status: 401)
  end

  def trusted_session
    render json: secure_session_confirmed? || user_just_created ? success_json : failed_json
  end

  def list_second_factors
    if SiteSetting.enable_discourse_connect || !SiteSetting.enable_local_logins
      raise Discourse::NotFound
    end

    if secure_session_confirmed?
      totp_second_factors =
        current_user
          .totps
          .select(:id, :name, :last_used, :created_at, :method)
          .where(enabled: true)
          .order(:created_at)
          .as_json(only: %i[id name method last_used])

      security_keys =
        current_user
          .security_keys
          .where(factor_type: UserSecurityKey.factor_types[:second_factor])
          .order(:created_at)
          .as_json(only: %i[id user_id credential_id public_key factor_type enabled name last_used])

      render json: success_json.merge(totps: totp_second_factors, security_keys: security_keys)
    else
      render json: success_json.merge(unconfirmed_session: true)
    end
  end

  def create_second_factor_backup
    backup_codes = current_user.generate_backup_codes

    render json: success_json.merge(backup_codes: backup_codes)
  end

  def create_second_factor_totp
    require "rotp" if !defined?(ROTP)
    totp_data = ROTP::Base32.random
    secure_session["staged-totp-#{current_user.id}"] = totp_data
    qrcode_png =
      RQRCode::QRCode.new(current_user.totp_provisioning_uri(totp_data)).as_png(
        border_modules: 1,
        size: 240,
      )

    render json:
             success_json.merge(key: totp_data.scan(/.{4}/).join(" "), qr: qrcode_png.to_data_url)
  end

  def create_second_factor_security_key
    if current_user.all_security_keys.count >= UserSecurityKey::MAX_KEYS_PER_USER
      render_json_error(I18n.t("login.too_many_security_keys"), status: 422)
      return
    end

    challenge_session = DiscourseWebauthn.stage_challenge(current_user, secure_session)
    render json:
             success_json.merge(
               challenge: challenge_session.challenge,
               rp_id: DiscourseWebauthn.rp_id,
               rp_name: DiscourseWebauthn.rp_name,
               supported_algorithms: ::DiscourseWebauthn::SUPPORTED_ALGORITHMS,
               user_secure_id: current_user.create_or_fetch_secure_identifier,
               existing_active_credential_ids:
                 current_user.second_factor_security_key_credential_ids,
             )
  end

  def register_second_factor_security_key
    params.require(:name)
    params.require(:attestation)
    params.require(:clientData)

    ::DiscourseWebauthn::RegistrationService.new(
      current_user,
      params,
      session: secure_session,
      factor_type: UserSecurityKey.factor_types[:second_factor],
    ).register_security_key
    render json: success_json
  rescue ::DiscourseWebauthn::SecurityKeyError => err
    render json: failed_json.merge(error: err.message)
  end

  def create_passkey
    raise Discourse::NotFound unless SiteSetting.enable_passkeys

    challenge_session = DiscourseWebauthn.stage_challenge(current_user, secure_session)
    render json:
             success_json.merge(
               challenge: challenge_session.challenge,
               rp_id: DiscourseWebauthn.rp_id,
               rp_name: DiscourseWebauthn.rp_name,
               supported_algorithms: ::DiscourseWebauthn::SUPPORTED_ALGORITHMS,
               user_secure_id: current_user.create_or_fetch_secure_identifier,
               existing_passkey_credential_ids: current_user.passkey_credential_ids,
             )
  end

  def register_passkey
    raise Discourse::NotFound unless SiteSetting.enable_passkeys

    params.require(:name)
    params.require(:attestation)
    params.require(:clientData)

    key =
      ::DiscourseWebauthn::RegistrationService.new(
        current_user,
        params,
        session: secure_session,
        factor_type: UserSecurityKey.factor_types[:first_factor],
      ).register_security_key

    render json: success_json.merge(id: key.id, name: key.name)
  rescue ::DiscourseWebauthn::SecurityKeyError => err
    render_json_error(err.message, status: 401)
  end

  def delete_passkey
    raise Discourse::NotFound unless SiteSetting.enable_passkeys

    current_user.security_keys.find_by(id: params[:id].to_i)&.destroy!

    render json: success_json
  end

  def rename_passkey
    raise Discourse::NotFound unless SiteSetting.enable_passkeys

    params.require(:id)
    params.require(:name)

    passkey = current_user.security_keys.find_by(id: params[:id].to_i)
    raise Discourse::InvalidParameters.new(:id) unless passkey

    passkey.update!(name: params[:name])
    render json: success_json
  end

  def update_security_key
    user_security_key = current_user.security_keys.find_by(id: params[:id].to_i)
    raise Discourse::InvalidParameters unless user_security_key

    user_security_key.update!(name: params[:name]) if params[:name] && !params[:name].blank?
    user_security_key.update!(enabled: false) if params[:disable] == "true"

    render json: success_json
  end

  def enable_second_factor_totp
    if params[:second_factor_token].blank?
      return render json: failed_json.merge(error: I18n.t("login.missing_second_factor_code"))
    end
    if params[:name].blank?
      return render json: failed_json.merge(error: I18n.t("login.missing_second_factor_name"))
    end
    auth_token = params[:second_factor_token]

    totp_data = secure_session["staged-totp-#{current_user.id}"]
    totp_object = current_user.get_totp_object(totp_data)

    rate_limit_second_factor!(current_user)

    authenticated =
      !auth_token.blank? &&
        totp_object.verify(
          auth_token,
          drift_ahead: SecondFactorManager::TOTP_ALLOWED_DRIFT_SECONDS,
          drift_behind: SecondFactorManager::TOTP_ALLOWED_DRIFT_SECONDS,
        )
    unless authenticated
      return render json: failed_json.merge(error: I18n.t("login.invalid_second_factor_code"))
    end
    current_user.create_totp(data: totp_data, name: params[:name], enabled: true)
    render json: success_json
  end

  def disable_second_factor
    # delete all second factors for a user
    current_user.user_second_factors.destroy_all
    current_user.second_factor_security_keys.destroy_all

    Jobs.enqueue(
      :critical_user_email,
      type: "account_second_factor_disabled",
      user_id: current_user.id,
    )

    render json: success_json
  end

  def update_second_factor
    params.require(:second_factor_target)
    update_second_factor_method = params[:second_factor_target].to_i

    if update_second_factor_method == UserSecondFactor.methods[:totp]
      params.require(:id)
      second_factor_id = params[:id].to_i
      user_second_factor = current_user.user_second_factors.totps.find_by(id: second_factor_id)
    elsif update_second_factor_method == UserSecondFactor.methods[:backup_codes]
      user_second_factor = current_user.user_second_factors.backup_codes
    end

    raise Discourse::InvalidParameters unless user_second_factor

    user_second_factor.update!(name: params[:name]) if params[:name] && !params[:name].blank?
    if params[:disable] == "true"
      # Disabling backup codes deletes *all* backup codes
      if update_second_factor_method == UserSecondFactor.methods[:backup_codes]
        current_user
          .user_second_factors
          .where(method: UserSecondFactor.methods[:backup_codes])
          .destroy_all
      else
        user_second_factor.update!(enabled: false)
      end
    end

    render json: success_json
  end

  def user_just_created
    current_user.created_at > 5.minutes.ago
  end

  def check_confirmed_session
    if SiteSetting.enable_discourse_connect || !SiteSetting.enable_local_logins
      raise Discourse::NotFound
    end

    raise Discourse::InvalidAccess.new if !current_user
    raise Discourse::InvalidAccess.new unless user_just_created || secure_session_confirmed?
  end

  def revoke_account
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)
    provider_name = params.require(:provider_name)

    # Using Discourse.authenticators rather than Discourse.enabled_authenticators so users can
    # revoke permissions even if the admin has temporarily disabled that type of login
    authenticator = Discourse.authenticators.find { |a| a.name == provider_name }
    raise Discourse::NotFound if authenticator.nil? || !authenticator.can_revoke?

    skip_remote = params.permit(:skip_remote)

    # We're likely going to contact the remote auth provider, so hijack request
    hijack do
      DiscourseEvent.trigger(:before_auth_revoke, authenticator, user)
      result = authenticator.revoke(user, skip_remote: skip_remote)
      if result
        render json: success_json
      else
        render json: {
                 success: false,
                 message: I18n.t("associated_accounts.revoke_failed", provider_name: provider_name),
               }
      end
    end
  end

  def revoke_auth_token
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)

    if params[:token_id]
      token = UserAuthToken.find_by(id: params[:token_id], user_id: user.id)
      # The user should not be able to revoke the auth token of current session.
      if !token || guardian.auth_token == token.auth_token
        raise Discourse::InvalidParameters.new(:token_id)
      end
      UserAuthToken.where(id: params[:token_id], user_id: user.id).each(&:destroy!)

      MessageBus.publish "/file-change", ["refresh"], user_ids: [user.id]
    else
      UserAuthToken.where(user_id: user.id).each(&:destroy!)
    end

    render json: success_json
  end

  def feature_topic
    user = fetch_user_from_params
    topic = Topic.find(params[:topic_id].to_i)

    if !guardian.can_feature_topic?(user, topic)
      return(
        render_json_error(
          I18n.t("activerecord.errors.models.user_profile.attributes.featured_topic_id.invalid"),
          403,
        )
      )
    end

    user.user_profile.update(featured_topic_id: topic.id)
    render json: success_json
  end

  def clear_featured_topic
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)
    user.user_profile.update(featured_topic_id: nil)
    render json: success_json
  end

  BOOKMARKS_LIMIT = 20

  def bookmarks
    user = fetch_user_from_params
    guardian.ensure_can_edit!(user)
    user_guardian = Guardian.new(user)

    respond_to do |format|
      format.json do
        bookmark_list =
          UserBookmarkList.new(
            user: user,
            guardian: guardian,
            search_term: params[:q],
            page: params[:page],
            per_page: fetch_limit_from_params(default: nil, max: BOOKMARKS_LIMIT),
          )

        bookmark_list.load

        if bookmark_list.bookmarks.empty?
          render json: { bookmarks: [] }
        else
          page = params[:page].to_i + 1
          bookmark_list.more_bookmarks_url =
            "#{Discourse.base_path}/u/#{params[:username]}/bookmarks.json?page=#{page}"
          render_serialized(bookmark_list, UserBookmarkListSerializer)
        end
      end
      format.ics do
        @bookmark_reminders =
          Bookmark
            .with_reminders
            .where(user_id: user.id)
            .order(:reminder_at)
            .map do |bookmark|
              bookmark.registered_bookmarkable.serializer.new(
                bookmark,
                scope: user_guardian,
                root: false,
              )
            end
      end
    end
  end

  USER_MENU_LIST_LIMIT = 20
  def user_menu_bookmarks
    if !current_user.username_equals_to?(params[:username])
      raise Discourse::InvalidAccess.new("username doesn't match current_user's username")
    end

    reminder_notifications =
      BookmarkQuery.new(user: current_user).unread_notifications(limit: USER_MENU_LIST_LIMIT)
    if reminder_notifications.size < USER_MENU_LIST_LIMIT
      exclude_bookmark_ids =
        reminder_notifications.filter_map { |notification| notification.data_hash[:bookmark_id] }

      bookmark_list =
        UserBookmarkList.new(
          user: current_user,
          guardian: guardian,
          per_page: USER_MENU_LIST_LIMIT - reminder_notifications.size,
        )

      bookmark_list.load do |query|
        if exclude_bookmark_ids.present?
          query.where("bookmarks.id NOT IN (?)", exclude_bookmark_ids)
        end
      end
    end

    if reminder_notifications.present?
      if SiteSetting.show_user_menu_avatars
        Notification.populate_acting_user(reminder_notifications)
      end
      serialized_notifications =
        ActiveModel::ArraySerializer.new(
          reminder_notifications,
          each_serializer: NotificationSerializer,
          scope: guardian,
        )
    end

    if bookmark_list
      bookmark_list.bookmark_serializer_opts = { link_to_first_unread_post: true }
      serialized_bookmarks =
        serialize_data(bookmark_list, UserBookmarkListSerializer, scope: guardian, root: false)[
          :bookmarks
        ]
    end

    render json: {
             notifications: serialized_notifications || [],
             bookmarks: serialized_bookmarks || [],
           }
  end

  def user_menu_messages
    if !current_user.username_equals_to?(params[:username])
      raise Discourse::InvalidAccess.new("username doesn't match current_user's username")
    end

    if !current_user.staff? &&
         !current_user.in_any_groups?(SiteSetting.personal_message_enabled_groups_map)
      raise Discourse::InvalidAccess.new("personal messages are disabled.")
    end

    unread_notifications =
      Notification
        .for_user_menu(current_user.id, limit: USER_MENU_LIST_LIMIT)
        .unread
        .where(
          notification_type: [
            Notification.types[:private_message],
            Notification.types[:group_message_summary],
          ],
        )
        .to_a

    if unread_notifications.size < USER_MENU_LIST_LIMIT
      exclude_topic_ids = unread_notifications.filter_map(&:topic_id).uniq
      limit = USER_MENU_LIST_LIMIT - unread_notifications.size

      messages_list =
        TopicQuery
          .new(current_user, per_page: limit)
          .list_private_messages_direct_and_groups(
            current_user,
            groups_messages_notification_level: :watching,
          ) do |query|
            if exclude_topic_ids.present?
              query.where("topics.id NOT IN (?)", exclude_topic_ids)
            else
              query
            end
          end

      read_notifications =
        Notification
          .for_user_menu(current_user.id, limit: limit)
          .where(read: true, notification_type: Notification.types[:group_message_summary])
          .to_a
    end

    if unread_notifications.present?
      Notification.populate_acting_user(unread_notifications) if SiteSetting.show_user_menu_avatars
      serialized_unread_notifications =
        ActiveModel::ArraySerializer.new(
          unread_notifications,
          each_serializer: NotificationSerializer,
          scope: guardian,
        )
    end

    if messages_list
      serialized_messages =
        serialize_data(messages_list, TopicListSerializer, scope: guardian, root: false)[:topics]
      serialized_users =
        if SiteSetting.show_user_menu_avatars
          users = messages_list.topics.map { |t| t.posters.last.user }.flatten.compact.uniq(&:id)
          serialize_data(users, BasicUserSerializer, scope: guardian, root: false)
        else
          []
        end
    end

    if read_notifications.present?
      Notification.populate_acting_user(read_notifications) if SiteSetting.show_user_menu_avatars
      serialized_read_notifications =
        ActiveModel::ArraySerializer.new(
          read_notifications,
          each_serializer: NotificationSerializer,
          scope: guardian,
        )
    end

    render json: {
             unread_notifications: serialized_unread_notifications || [],
             read_notifications: serialized_read_notifications || [],
             topics: serialized_messages || [],
             users: serialized_users || [],
           }
  end

  private

  def clean_custom_field_values(field)
    field_values = params[:user_fields][field.id.to_s]

    return field_values if field_values.nil? || field_values.empty?

    if field.field_type == "dropdown"
      field.user_field_options.find_by_value(field_values)&.value
    elsif field.field_type == "multiselect"
      field_values = Array.wrap(field_values)
      bad_values = field_values - field.user_field_options.map(&:value)
      field_values - bad_values
    else
      field_values
    end
  end

  def password_reset_find_user(token, committing_change:)
    @user =
      if committing_change
        EmailToken.confirm(token, scope: EmailToken.scopes[:password_reset])
      else
        EmailToken.confirmable(token, scope: EmailToken.scopes[:password_reset])&.user
      end

    if @user
      secure_session["password-#{token}"] = @user.id
    else
      user_id = secure_session["password-#{token}"].to_i
      @user = User.find(user_id) if user_id > 0
    end

    @error = I18n.t("password_reset.no_token", base_url: Discourse.base_url) if !@user
  end

  def respond_to_suspicious_request
    if suspicious?(params)
      render json: {
               success: true,
               active: false,
               message: I18n.t("login.activate_email", email: params[:email]),
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
    permitted = %i[
      name
      email
      password
      username
      title
      date_of_birth
      muted_usernames
      allowed_pm_usernames
      theme_ids
      locale
      bio_raw
      location
      website
      dismissed_banner_key
      profile_background_upload_url
      card_background_upload_url
      primary_group_id
      flair_group_id
      featured_topic_id
    ]

    editable_custom_fields = User.editable_user_custom_fields(by_staff: current_user.try(:staff?))
    permitted << { custom_fields: editable_custom_fields } if editable_custom_fields.present?
    permitted.concat UserUpdater::OPTION_ATTR
    permitted.concat UserUpdater::CATEGORY_IDS.keys.map { |k| { k => [] } }
    permitted.concat UserUpdater::TAG_NAMES.keys
    permitted << UserUpdater::NOTIFICATION_SCHEDULE_ATTRS

    if params.has_key?(:sidebar_category_ids) && params[:sidebar_category_ids].blank?
      params[:sidebar_category_ids] = []
    end

    permitted << { sidebar_category_ids: [] }

    if SiteSetting.tagging_enabled
      if params.has_key?(:sidebar_tag_names) && params[:sidebar_tag_names].blank?
        params[:sidebar_tag_names] = []
      end

      permitted << { sidebar_tag_names: [] }
    end

    if SiteSetting.enable_user_status
      permitted << :status
      permitted << { status: %i[emoji description ends_at] }
    end

    result =
      params.permit(permitted, theme_ids: [], seen_popups: []).reverse_merge(
        ip_address: request.remote_ip,
        registration_ip_address: request.remote_ip,
      )

    if !UsernameCheckerService.is_developer?(result["email"]) && is_api? && current_user.present? &&
         current_user.admin?
      result.merge!(params.permit(:active, :staged, :approved))
    end

    DiscoursePluginRegistry.apply_modifier(
      :users_controller_update_user_params,
      result,
      current_user,
      params,
    )
  end

  def fail_with(key)
    render json: { success: false, message: I18n.t(key) }
  end

  def track_visit_to_user_profile
    user_profile_id = @user.user_profile.id
    ip = request.remote_ip
    user_id = (current_user.id if current_user)

    Scheduler::Defer.later "Track profile view visit" do
      UserProfileView.add(user_profile_id, ip, user_id)
    end
  end

  def clashing_with_existing_route?(username)
    normalized_username = User.normalize_username(username)
    http_verbs = %w[GET POST PUT DELETE PATCH]
    allowed_actions = %w[show update destroy]

    http_verbs.any? do |verb|
      begin
        path = Rails.application.routes.recognize_path("/u/#{normalized_username}", method: verb)
        allowed_actions.exclude?(path[:action])
      rescue ActionController::RoutingError
        false
      end
    end
  end

  def confirm_secure_session
    RateLimiter.new(
      nil,
      "login-hr-#{request.remote_ip}",
      SiteSetting.max_logins_per_ip_per_hour,
      1.hour,
    ).performed!
    RateLimiter.new(
      nil,
      "login-min-#{request.remote_ip}",
      SiteSetting.max_logins_per_ip_per_minute,
      1.minute,
    ).performed!

    if !params[:password].present? && !params[:publicKeyCredential].present?
      raise Discourse::InvalidParameters.new "Missing password or passkey"
    end

    if params[:password].present?
      return false if !current_user.confirm_password?(params[:password])
    end

    if params[:publicKeyCredential].present?
      passkey =
        ::DiscourseWebauthn::AuthenticationService.new(
          current_user,
          params[:publicKeyCredential],
          session: secure_session,
          factor_type: UserSecurityKey.factor_types[:first_factor],
        ).authenticate_security_key

      return false if !passkey
    end

    secure_session["confirmed-session-#{current_user.id}"] = "true"
  end

  def secure_session_confirmed?
    secure_session["confirmed-session-#{current_user.id}"] == "true"
  end

  def summary_cache_key(user)
    "user_summary:#{user.id}:#{current_user ? current_user.id : 0}"
  end

  def render_invite_error(message)
    render json: { invites: [], can_see_invite_details: false, error: message }
  end

  def serialize_found_users(users)
    serializer =
      ActiveModel::ArraySerializer.new(
        users,
        each_serializer: FoundUserSerializer,
        include_status: true,
      )
    { users: serializer.as_json }
  end
end
