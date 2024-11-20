# frozen_string_literal: true

class AdminUserListSerializer < BasicUserSerializer
  attributes :email,
             :secondary_emails,
             :active,
             :admin,
             :moderator,
             :last_seen_at,
             :last_emailed_at,
             :created_at,
             :last_seen_age,
             :last_emailed_age,
             :created_at_age,
             :trust_level,
             :manual_locked_trust_level,
             :username,
             :title,
             :avatar_template,
             :approved,
             :suspended_at,
             :suspended_till,
             :silenced,
             :silenced_till,
             :time_read,
             :staged,
             :second_factor_enabled,
             :can_be_deleted

  %i[days_visited posts_read_count topics_entered post_count].each do |sym|
    attributes sym
    define_method sym do
      object.user_stat.public_send(sym)
    end
  end

  def include_email?
    # staff members can always see their email
    (scope.is_staff? && (object.id == scope.user.id || object.staged?)) ||
      (@options[:emails_desired] && scope.can_check_emails?(object))
  end

  alias_method :include_secondary_emails?, :include_email?
  alias_method :include_associated_accounts?, :include_email?

  def silenced
    object.silenced?
  end

  def include_silenced?
    object.silenced?
  end

  def silenced_till
    object.silenced_till
  end

  def include_silenced_till?
    object.silenced_till?
  end

  def include_suspended_at?
    object.suspended?
  end

  def include_suspended_till?
    object.suspended?
  end

  def can_impersonate
    scope.can_impersonate?(object)
  end

  def last_emailed_at
    return nil if object.last_emailed_at.blank?
    object.last_emailed_at
  end

  def last_emailed_age
    return nil if object.last_emailed_at.blank?
    Time.now - object.last_emailed_at
  end

  def last_seen_at
    return nil if object.last_seen_at.blank?
    object.last_seen_at
  end

  def last_seen_age
    return nil if object.last_seen_at.blank?
    Time.now - object.last_seen_at
  end

  def time_read
    return nil if object.user_stat.time_read.blank?
    object.user_stat.time_read
  end

  def created_at_age
    Time.now - object.created_at
  end

  def include_approved?
    SiteSetting.must_approve_users
  end

  def include_second_factor_enabled?
    !SiteSetting.enable_discourse_connect && SiteSetting.enable_local_logins &&
      object.has_any_second_factor_methods_enabled?
  end

  def second_factor_enabled
    true
  end

  def can_be_deleted
    scope.can_delete_user?(object)
  end

  def include_can_be_deleted?
    @options[:include_can_be_deleted]
  end
end
