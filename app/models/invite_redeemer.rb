# frozen_string_literal: true

InviteRedeemer = Struct.new(:invite, :email, :username, :name, :password, :user_custom_fields, :ip_address, :session, :email_token, keyword_init: true) do

  def redeem
    Invite.transaction do
      if invite_was_redeemed?
        process_invitation
        invited_user
      end
    end
  end

  # extracted from User cause it is very specific to invites
  def self.create_user_from_invite(email:, invite:, username: nil, name: nil, password: nil, user_custom_fields: nil, ip_address: nil, session: nil, email_token: nil)
    if username && UsernameValidator.new(username).valid_format? && User.username_available?(username, email)
      available_username = username
    else
      available_username = UserNameSuggester.suggest(email)
    end

    if email.present? && invite.domain.present?
      username, domain = email.split('@')
      if domain.present? && invite.domain != domain
        raise ActiveRecord::RecordNotSaved.new(I18n.t('invite.domain_not_allowed'))
      end
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
      registration_ip_address: ip_address
    }

    if !SiteSetting.must_approve_users? ||
        (SiteSetting.must_approve_users? && invite.invited_by.staff?) ||
        EmailValidator.can_auto_approve_user?(user.email)
      ReviewableUser.set_approved_fields!(user, invite.invited_by)
    end

    user_fields = UserField.all
    if user_custom_fields.present? && user_fields.present?
      field_params = user_custom_fields || {}
      fields = user.custom_fields

      user_fields.each do |f|
        field_val = field_params[f.id.to_s]
        fields["#{User::USER_FIELD_PREFIX}#{f.id}"] = field_val[0...UserField.max_length] unless field_val.blank?
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

    if invite.emailed_status != Invite.emailed_status_types[:not_required] && email == invite.email && invite.email_token.present? && email_token == invite.email_token
      user.email_tokens.create!(email: user.email, scope: EmailToken.scopes[:signup])
      user.activate
    end

    User.find(user.id)
  end

  private

  def invited_user
    @invited_user ||= get_invited_user
  end

  def process_invitation
    approve_account_if_needed
    add_to_private_topics_if_invited
    add_user_to_groups
    send_welcome_message
    notify_invitee
  end

  def invite_was_redeemed?
    mark_invite_redeemed
  end

  def mark_invite_redeemed
    if !invite.is_invite_link? && InvitedUser.exists?(invite_id: invite.id)
      return false
    end

    existing_user = get_existing_user
    if existing_user.present? && InvitedUser.exists?(user_id: existing_user.id, invite_id: invite.id)
      return false
    end

    @invited_user_record = InvitedUser.create!(invite_id: invite.id, redeemed_at: Time.zone.now)
    if @invited_user_record.present?
      Invite.increment_counter(:redemption_count, invite.id)
      delete_duplicate_invites
    end

    @invited_user_record.present?
  end

  def get_invited_user
    result = get_existing_user
    result ||= InviteRedeemer.create_user_from_invite(
      email: email,
      invite: invite,
      username: username,
      name: name,
      password: password,
      user_custom_fields: user_custom_fields,
      ip_address: ip_address,
      session: session,
      email_token: email_token
    )
    result.send_welcome_message = false
    result
  end

  def get_existing_user
    User.where(admin: false, staged: false).find_by_email(email)
  end

  def add_to_private_topics_if_invited
    topic_ids = Topic.where(archetype: Archetype::private_message).includes(:invites).where(invites: { email: email }).pluck(:id)
    topic_ids.each do |id|
      TopicAllowedUser.create!(user_id: invited_user.id, topic_id: id) unless TopicAllowedUser.exists?(user_id: invited_user.id, topic_id: id)
    end
  end

  def add_user_to_groups
    guardian = Guardian.new(invite.invited_by)
    new_group_ids = invite.groups.pluck(:id) - invited_user.group_users.pluck(:group_id)
    new_group_ids.each do |id|
      group = Group.find_by(id: id)
      if guardian.can_edit_group?(group)
        invited_user.group_users.create!(group_id: group.id)
        DiscourseEvent.trigger(:user_added_to_group, invited_user, group, automatic: false)
      end
    end
  end

  def send_welcome_message
    @invited_user_record.update!(user_id: invited_user.id)
    invited_user.send_welcome_message = true
  end

  def approve_account_if_needed
    if invited_user.present? && reviewable_user = ReviewableUser.find_by(target: invited_user, status: Reviewable.statuses[:pending])
      reviewable_user.perform(
        invite.invited_by,
        :approve_user,
        send_email: false,
        approved_by_invite: true
      )
    end
  end

  def notify_invitee
    if inviter = invite.invited_by
      inviter.notifications.create!(
        notification_type: Notification.types[:invitee_accepted],
        data: { display_username: invited_user.username }.to_json
      )
    end
  end

  def delete_duplicate_invites
    Invite
      .where('invites.max_redemptions_allowed = 1')
      .joins("LEFT JOIN invited_users ON invites.id = invited_users.invite_id")
      .where('invited_users.user_id IS NULL')
      .where('invites.email = ? AND invites.id != ?', email, invite.id)
      .delete_all
  end
end
