# frozen_string_literal: true

# NOTE: There are a _lot_ of complicated rules and conditions for our
# invite system, and the code is spread out through a lot of places.
# Tread lightly and read carefully when modifying this code. You may
# also want to look at:
#
# * InvitesController
# * SessionController
# * Invite model
# * User model
#
# Invites that are scoped to a specific email (email IS NOT NULL on the Invite
# model) have different rules to invites that are considered an "invite link",
# (email IS NULL) on the Invite model.
class InviteRedeemer
  attr_reader :invite,
              :email,
              :username,
              :name,
              :password,
              :user_custom_fields,
              :ip_address,
              :session,
              :email_token,
              :redeeming_user

  def initialize(
    invite:,
    email: nil,
    username: nil,
    name: nil,
    password: nil,
    user_custom_fields: nil,
    ip_address: nil,
    session: nil,
    email_token: nil,
    redeeming_user: nil
  )
    @invite = invite
    @username = username
    @name = name
    @password = password
    @user_custom_fields = user_custom_fields
    @ip_address = ip_address
    @session = session
    @email_token = email_token
    @redeeming_user = redeeming_user

    ensure_email_is_present!(email)
  end

  def redeem
    Invite.transaction do
      if can_redeem_invite? && mark_invite_redeemed
        process_invitation
        invited_user
      end
    end
  end

  # The email must be present in some form since many of the methods
  # for processing + redemption rely on it. If it's still nil after
  # these checks then we have hit an edge case and should not proceed!
  def ensure_email_is_present!(email)
    if email.blank?
      Rails.logger.warn(
        "email param was blank in InviteRedeemer for invite ID #{@invite.id}. The `redeeming_user` was #{@redeeming_user.present? ? "(ID: #{@redeeming_user.id})" : "not"} present.",
      )
    end

    if email.blank? && @invite.is_email_invite?
      @email = @invite.email
    elsif @redeeming_user.present?
      @email = @redeeming_user.email
    else
      @email = email
    end

    raise Discourse::InvalidParameters if @email.blank?
  end

  # This will _never_ be called if there is a redeeming_user being passed
  # in to InviteRedeemer -- see invited_user below.
  def self.create_user_from_invite(
    email:,
    invite:,
    username: nil,
    name: nil,
    password: nil,
    user_custom_fields: nil,
    ip_address: nil,
    session: nil,
    email_token: nil
  )
    if username && UsernameValidator.new(username).valid_format? &&
         User.username_available?(username, email)
      available_username = username
    else
      available_username = UserNameSuggester.suggest(email)
    end

    user = User.where(staged: true).with_email(email.strip.downcase).first
    user.unstage! if user
    user ||= User.new

    user.attributes = {
      email: email,
      username: available_username,
      name: name || available_username,
      active: false,
      trust_level: SiteSetting.default_invitee_trust_level,
      ip_address: ip_address,
      registration_ip_address: ip_address,
    }

    if (!SiteSetting.must_approve_users && SiteSetting.invite_only) ||
         (SiteSetting.must_approve_users? && EmailValidator.can_auto_approve_user?(user.email))
      ReviewableUser.set_approved_fields!(user, Discourse.system_user)
    end

    user_fields = UserField.all
    if user_custom_fields.present? && user_fields.present?
      field_params = user_custom_fields || {}
      fields = user.custom_fields

      user_fields.each do |f|
        field_params[f.id.to_s] = nil if field_params[f.id.to_s] === "false"
        field_val = field_params[f.id.to_s]
        fields["#{User::USER_FIELD_PREFIX}#{f.id}"] = field_val[
          0...UserField.max_length
        ] if field_val.present?
      end
      user.custom_fields = fields
    end

    user.moderator = true if invite.moderator? && invite.invited_by.staff?

    if password
      user.password = password
      user.password_required!
    end

    authenticator = UserAuthenticator.new(user, session, require_password: false)

    if !authenticator.has_authenticator? && !SiteSetting.enable_local_logins
      raise ActiveRecord::RecordNotSaved.new(I18n.t("login.incorrect_username_email_or_password"))
    end

    authenticator.start

    if authenticator.email_valid? && !authenticator.authenticated?
      raise ActiveRecord::RecordNotSaved.new(I18n.t("login.incorrect_username_email_or_password"))
    end

    user.save!
    authenticator.finish

    if invite.emailed_status != Invite.emailed_status_types[:not_required] &&
         email == invite.email && invite.email_token.present? && email_token == invite.email_token
      user.activate
    end

    User.find(user.id)
  end

  private

  def can_redeem_invite?
    return false if !invite.redeemable?
    return false if email.blank?

    # Invite scoped to email has already been redeemed by anyone.
    return false if invite.is_email_invite? && InvitedUser.exists?(invite_id: invite.id)

    # The email will be present for either an invite link (where the user provides
    # us the email manually) or for an invite scoped to an email, where we
    # prefill the email and do not let the user modify it.
    #
    # Note that an invite link can also have a domain scope which must be checked.
    email_to_check = redeeming_user&.email || email

    if invite.email.present? && !invite.email_matches?(email_to_check)
      raise ActiveRecord::RecordNotSaved.new(I18n.t("invite.not_matching_email"))
    end

    if invite.domain.present? && !invite.domain_matches?(email_to_check)
      raise ActiveRecord::RecordNotSaved.new(I18n.t("invite.domain_not_allowed"))
    end

    # Anon user is trying to redeem an invitation, if an existing user already
    # redeemed it then we cannot redeem now.
    redeeming_user ||= User.where(admin: false, staged: false).find_by_email(email)
    if redeeming_user.present? &&
         InvitedUser.exists?(user_id: redeeming_user.id, invite_id: invite.id)
      raise Invite::UserExists.new(I18n.t("invite.existing_user_already_redemeed"))
    end

    true
  end

  # Note that the invited_user is returned by #redeemed, so other places
  # (e.g. the InvitesController) can perform further actions on it, this
  # is why things like send_welcome_message are set without being saved
  # on the model.
  def invited_user
    return @invited_user if defined?(@invited_user)

    # The redeeming user is an already logged in user or a user who is
    # activating their account who is redeeming the invite,
    # which is valid for existing users to be invited to topics or groups.
    if redeeming_user.present?
      @invited_user = redeeming_user
      return @invited_user
    end

    # If there was no logged in user then we must attempt to create
    # one based on the provided params.
    invited_user ||=
      InviteRedeemer.create_user_from_invite(
        email: email,
        invite: invite,
        username: username,
        name: name,
        password: password,
        user_custom_fields: user_custom_fields,
        ip_address: ip_address,
        session: session,
        email_token: email_token,
      )
    invited_user.send_welcome_message = false
    @invited_user = invited_user
    @invited_user
  end

  def process_invitation
    add_to_private_topics_if_invited
    add_user_to_groups
    send_welcome_message
    notify_invitee
  end

  def mark_invite_redeemed
    @invited_user_record = InvitedUser.create!(invite_id: invite.id, redeemed_at: Time.zone.now)

    if @invited_user_record.present?
      invite.with_lock("FOR UPDATE NOWAIT") do
        Invite.increment_counter(:redemption_count, invite.id)
        invite.save!
      end
      delete_duplicate_invites
    end

    @invited_user_record.present?
  end

  def add_to_private_topics_if_invited
    # Should not happen because of ensure_email_is_present!, but better to cover bases.
    return if email.blank?

    topic_ids =
      TopicInvite
        .joins(:invite)
        .joins(:topic)
        .where("topics.archetype = ?", Archetype.private_message)
        .where("invites.email = ?", email)
        .pluck(:topic_id)
    topic_ids.each do |id|
      if !TopicAllowedUser.exists?(user_id: invited_user.id, topic_id: id)
        TopicAllowedUser.create!(user_id: invited_user.id, topic_id: id)
      end
    end
  end

  def add_user_to_groups
    guardian = Guardian.new(invite.invited_by)
    new_group_ids = invite.groups.pluck(:id) - invited_user.group_users.pluck(:group_id)
    new_group_ids.each do |id|
      group = Group.find_by(id: id)
      if guardian.can_edit_group?(group)
        invited_user.group_users.create!(group_id: group.id)
        GroupActionLogger.new(invite.invited_by, group).log_add_user_to_group(invited_user)
        DiscourseEvent.trigger(:user_added_to_group, invited_user, group, automatic: false)
      end
    end
  end

  def send_welcome_message
    @invited_user_record.update!(user_id: invited_user.id)
    invited_user.send_welcome_message = true
  end

  def notify_invitee
    return if invite.invited_by.blank?
    invite.invited_by.notifications.create!(
      notification_type: Notification.types[:invitee_accepted],
      data: { display_username: invited_user.username }.to_json,
    )
  end

  def delete_duplicate_invites
    # Should not happen because of ensure_email_is_present!, but better to cover bases.
    return if email.blank?

    Invite
      .where("invites.max_redemptions_allowed = 1")
      .joins("LEFT JOIN invited_users ON invites.id = invited_users.invite_id")
      .where("invited_users.user_id IS NULL")
      .where("invites.email = ? AND invites.id != ?", email, invite.id)
      .delete_all
  end
end
