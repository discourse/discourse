InviteRedeemer = Struct.new(:invite, :username, :name, :password, :user_custom_fields) do

  def redeem
    Invite.transaction do
      if invite_was_redeemed?
        process_invitation
        return invited_user
      end
    end

    nil
  end

  # extracted from User cause it is very specific to invites
  def self.create_user_from_invite(invite, username, name, password = nil, user_custom_fields = nil)
    if username && UsernameValidator.new(username).valid_format? && User.username_available?(username)
      available_username = username
    else
      available_username = UserNameSuggester.suggest(invite.email)
    end
    available_name = name || available_username

    user_params = {
      email: invite.email,
      username: available_username,
      name: available_name,
      active: true,
      trust_level: SiteSetting.default_invitee_trust_level
    }

    user = User.unstage(user_params)
    user = User.new(user_params) if user.nil?

    if !SiteSetting.must_approve_users? || (SiteSetting.must_approve_users? && invite.invited_by.staff?)
      user.approved = true
      user.approved_by_id = invite.invited_by_id
      user.approved_at = Time.zone.now
    end

    user_fields = UserField.all
    if user_custom_fields.present? && user_fields.present?
      field_params = user_custom_fields || {}
      fields = user.custom_fields

      user_fields.each do |f|
        field_val = field_params[f.id.to_s]
        fields["user_field_#{f.id}"] = field_val[0...UserField.max_length] unless field_val.blank?
      end
      user.custom_fields = fields
    end

    user.moderator = true if invite.moderator? && invite.invited_by.staff?

    if password
      user.password = password
      user.password_required!
    end

    user.save!
    User.find(user.id)
  end

  private

  def invited_user
    @invited_user ||= get_invited_user
  end

  def process_invitation
    approve_account_if_needed
    add_to_private_topics_if_invited
    add_user_to_invited_topics
    add_user_to_groups
    send_welcome_message
    notify_invitee
    delete_duplicate_invites
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
    result ||= InviteRedeemer.create_user_from_invite(invite, username, name, password, user_custom_fields)
    result.send_welcome_message = false
    result
  end

  def get_existing_user
    User.where(admin: false, staged: false).find_by_email(invite.email)
  end

  def add_to_private_topics_if_invited
    invite.topics.private_messages.each do |t|
      t.topic_allowed_users.create(user_id: invited_user.id)
    end
  end

  def add_user_to_invited_topics
    Invite.where('invites.email = ? and invites.id != ?', invite.email, invite.id).includes(:topics).where(topics: { archetype: Archetype::private_message }).each do |i|
      i.topics.each do |t|
        t.topic_allowed_users.create(user_id: invited_user.id)
      end
    end
  end

  def add_user_to_groups
    new_group_ids = invite.groups.pluck(:id) - invited_user.group_users.pluck(:group_id)
    new_group_ids.each do |id|
      invited_user.group_users.create(group_id: id)
    end
  end

  def send_welcome_message
    if Invite.where(['email = ?', invite.email]).update_all(['user_id = ?', invited_user.id]) == 1
      invited_user.send_welcome_message = true
    end
  end

  def approve_account_if_needed
    if get_existing_user
      invited_user.approve(invite.invited_by_id, false)
    end
  end

  def notify_invitee
    if inviter = invite.invited_by
      inviter.notifications.create(notification_type: Notification.types[:invitee_accepted],
                                   data: { display_username: invited_user.username }.to_json)
    end
  end

  def delete_duplicate_invites
    Invite.where('invites.email = ? AND redeemed_at IS NULL AND invites.id != ?', invite.email, invite.id).delete_all
  end
end
