InviteRedeemer = Struct.new(:invite, :username, :name) do

  def redeem
    Invite.transaction do
      if invite_was_redeemed?
        process_invitation
        return invited_user
      end
    end

    # If `invite_passthrough_hours` is defined, allow them to re-use the invite link
    # to login again.
    if invite.redeemed_at && invite.redeemed_at >= SiteSetting.invite_passthrough_hours.hours.ago
      return invited_user
    end

    nil
  end

  # extracted from User cause it is very specific to invites
  def self.create_user_from_invite(invite, username, name)
    user_exists = User.find_by_email(invite.email)
    return user if user_exists

    if username && UsernameValidator.new(username).valid_format? && User.username_available?(username)
      available_username = username
    else
      available_username = UserNameSuggester.suggest(invite.email)
    end
    available_name = name || available_username

    user = User.new(email: invite.email, username: available_username, name: available_name, active: true, trust_level: SiteSetting.default_invitee_trust_level)
    user.save!

    user
  end

  private

  def invited_user
    @invited_user ||= get_invited_user
  end

  def process_invitation
    add_to_private_topics_if_invited
    add_user_to_invited_topics
    add_user_to_groups
    send_welcome_message
    approve_account_if_needed
    notify_invitee
    send_password_instructions
  end

  def invite_was_redeemed?
    # Return true if a row was updated
    mark_invite_redeemed == 1
  end

  def mark_invite_redeemed
    Invite.where(['id = ? AND redeemed_at IS NULL AND created_at >= ?',
                       invite.id, SiteSetting.invite_expiry_days.days.ago]).update_all('redeemed_at = CURRENT_TIMESTAMP')
  end

  def get_invited_user
    result = get_existing_user
    result ||= InviteRedeemer.create_user_from_invite(invite, username, name)
    result.send_welcome_message = false
    result
  end

  def get_existing_user
    User.find_by(email: invite.email)
  end


  def add_to_private_topics_if_invited
    invite.topics.private_messages.each do |t|
      t.topic_allowed_users.create(user_id: invited_user.id)
    end
  end

  def add_user_to_invited_topics
    Invite.where('invites.email = ? and invites.id != ?', invite.email, invite.id).includes(:topics).where(topics: {archetype: Archetype::private_message}).each do |i|
      i.topics.each do |t|
        t.topic_allowed_users.create(user_id: invited_user.id)
      end
    end
  end

  def add_user_to_groups
    invite.groups.each do |g|
      invited_user.group_users.create(group_id: g.id)
    end
  end

  def send_welcome_message
    if Invite.where(['email = ?', invite.email]).update_all(['user_id = ?', invited_user.id]) == 1
      invited_user.send_welcome_message = true
    end
  end

  def approve_account_if_needed
    invited_user.approve(invite.invited_by_id, false)
  end

  def send_password_instructions
    if !SiteSetting.enable_sso && SiteSetting.enable_local_logins && !invited_user.has_password?
      Jobs.enqueue(:invite_password_instructions_email, username: invited_user.username)
    end
  end

  def notify_invitee
    invite.invited_by.notifications.create(notification_type: Notification.types[:invitee_accepted],
                                           data: {display_username: invited_user.username}.to_json)
  end
end
