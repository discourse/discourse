InviteRedeemer = Struct.new(:invite) do

  def redeem
    Invite.transaction do
      if invite_was_redeemed?
        process_invitation
        return invited_user
      end
    end

    # If `invite_passthrough_hours` is defined, allow them to re-use the invite link
    # to login again.
    if invite.redeemed_at >= SiteSetting.invite_passthrough_hours.hours.ago
      return invited_user
    end

    nil
  end

  # extracted from User cause it is very specific to invites
  def self.create_user_from_invite(invite)

    user_exists = User.find_by_email(invite.email)
    return user if user_exists

    username = UserNameSuggester.suggest(invite.email)

    DiscourseHub.username_operation do
      match, available, suggestion = DiscourseHub.username_match?(username, invite.email)
      username = suggestion unless match || available
    end

    user = User.new(email: invite.email, username: username, name: username, active: true, trust_level: SiteSetting.default_invitee_trust_level)
    user.save!

    DiscourseHub.username_operation { DiscourseHub.register_username(username, invite.email) }

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
    result ||= InviteRedeemer.create_user_from_invite(invite)
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
    invited_user.approve(invite.invited_by_id, send_email=false)
  end

  def notify_invitee
    invite.invited_by.notifications.create(notification_type: Notification.types[:invitee_accepted],
                                           data: {display_username: invited_user.username}.to_json)
  end
end
