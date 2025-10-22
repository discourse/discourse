# frozen_string_literal: true

module InviteGuardian
  def can_see_invite_details?(user)
    is_staff? || is_me?(user)
  end

  def can_see_invite_emails?(user)
    is_staff? || is_me?(user)
  end

  def can_invite_to_forum?(groups = nil)
    return false if !authenticated?
    return false if !@user.in_any_groups?(SiteSetting.invite_allowed_groups_map)
    return false if !SiteSetting.max_invites_per_day.to_i.positive? && !is_staff?

    groups.blank? || groups.all? { |g| can_edit_group?(g) }
  end

  def can_invite_to?(object, groups = nil)
    return false if !authenticated?
    return false if !object.is_a?(Topic) || !can_see?(object)
    return false if groups.present?

    if object.is_a?(Topic)
      if object.private_message?
        return true if is_admin?

        return false if !@user.in_any_groups?(SiteSetting.personal_message_enabled_groups_map)
        return false if object.reached_recipients_limit? && !is_staff?
      end

      if (category = object.category) && category.read_restricted
        return category.groups&.where(automatic: false)&.any? { |g| can_edit_group?(g) }
      end
    end

    true
  end

  def can_invite_via_email?(object)
    return false if !can_invite_to_forum?
    return false if !can_invite_to?(object)

    (SiteSetting.enable_local_logins || SiteSetting.enable_discourse_connect) &&
      (!SiteSetting.must_approve_users? || is_staff?)
  end

  def can_bulk_invite_to_forum?
    is_admin?
  end

  def can_resend_all_invites?
    is_staff?
  end

  def can_destroy_all_invites?
    is_staff?
  end

  def can_destroy_invite?(invite)
    invite && (is_admin? || is_me?(invite.invited_by))
  end
end
