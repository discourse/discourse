class AdminUserListSerializer < BasicUserSerializer

  attributes :email,
             :active,
             :admin,
             :moderator,
             :last_seen_at,
             :last_emailed_at,
             :created_at,
             :last_seen_age,
             :last_emailed_age,
             :created_at_age,
             :username_lower,
             :trust_level,
             :trust_level_locked,
             :flag_level,
             :username,
             :title,
             :avatar_template,
             :can_approve,
             :approved,
             :suspended_at,
             :suspended_till,
             :suspended,
             :blocked,
             :time_read,
             :staged

  [:days_visited, :posts_read_count, :topics_entered, :post_count].each do |sym|
    attributes sym
    define_method sym do
      object.user_stat.send(sym)
    end
  end

  def include_email?
    # staff members can always see their email
    (scope.is_staff? && object.id == scope.user.id) || scope.can_see_emails?
  end

  alias_method :include_associated_accounts?, :include_email?

  def suspended
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
    AgeWords.age_words(Time.now - object.last_emailed_at)
  end

  def last_seen_at
    return nil if object.last_seen_at.blank?
    object.last_seen_at
  end

  def last_seen_age
    return nil if object.last_seen_at.blank?
    AgeWords.age_words(Time.now - object.last_seen_at)
  end

  def time_read
    return nil if object.user_stat.time_read.blank?
    AgeWords.age_words(object.user_stat.time_read)
  end

  def created_at_age
    AgeWords.age_words(Time.now - object.created_at)
  end

  def can_approve
    scope.can_approve?(object)
  end

  def include_can_approve?
    SiteSetting.must_approve_users
  end

  def include_approved?
    SiteSetting.must_approve_users
  end

end
