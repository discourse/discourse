class AdminUserSerializer < BasicUserSerializer

  attributes :email,
             :active,
             :admin,
             :moderator,
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
             :ip_address,
             :registration_ip_address,
             :can_send_activation_email,
             :can_activate,
             :can_deactivate,
             :blocked,
             :time_read,
             :associated_accounts

  has_one :single_sign_on_record, serializer: SingleSignOnRecordSerializer, embed: :objects

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

  def last_emailed_age
    return nil if object.last_emailed_at.blank?
    AgeWords.age_words(Time.now - object.last_emailed_at)
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

  def can_send_activation_email
    scope.can_send_activation_email?(object)
  end

  def can_activate
    scope.can_activate?(object)
  end

  def can_deactivate
    scope.can_deactivate?(object)
  end

  def ip_address
    object.ip_address.try(:to_s)
  end

  def registration_ip_address
    object.registration_ip_address.try(:to_s)
  end

end
