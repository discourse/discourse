require_dependency 'email_token'
require_dependency 'trust_level'

class User < ActiveRecord::Base

  attr_accessible :name, :username, :password, :email, :bio_raw, :website

  has_many :posts
  has_many :notifications
  has_many :topic_users
  has_many :topics
  has_many :user_open_ids
  has_many :user_actions
  has_many :post_actions
  has_many :email_logs
  has_many :post_timings
  has_many :topic_allowed_users
  has_many :topics_allowed, through: :topic_allowed_users, source: :topic
  has_many :email_tokens
  has_many :views
  has_many :user_visits
  has_many :invites
  has_one :twitter_user_info
  belongs_to :approved_by, class_name: 'User'

  validates_presence_of :username
  validates_presence_of :email
  validates_uniqueness_of :email
  validate :username_validator
  validate :email_validator, :if => :email_changed?
  validate :password_validator

  before_save :cook
  before_save :update_username_lower
  before_save :ensure_password_is_hashed
  after_initialize :add_trust_level

  after_save :update_tracked_topics

  after_create :create_email_token

  # Whether we need to be sending a system message after creation
  attr_accessor :send_welcome_message

  # This is just used to pass some information into the serializer
  attr_accessor :notification_channel_position

  module NewTopicDuration
    ALWAYS = -1 
    LAST_VISIT = -2
  end

  def self.username_length
    3..15
  end

  def self.suggest_username(name)

    return nil unless name.present?
    
    # If it's an email
    if name =~ /([^@]+)@([^\.]+)/
      name = Regexp.last_match[1]

      # Special case, if it's me @ something, take the something.
      name = Regexp.last_match[2] if name == 'me'
    end

    name.gsub!(/^[^A-Za-z0-9]+/, "")
    name.gsub!(/[^A-Za-z0-9_]+$/, "")
    name.gsub!(/[^A-Za-z0-9_]+/, "_")

    # Pad the length with 1s
    missing_chars = User.username_length.begin - name.length
    name << ('1' * missing_chars) if missing_chars > 0

    # Trim extra length
    name = name[0..User.username_length.end-1]

    i = 1
    attempt = name
    while !username_available?(attempt)
      suffix = i.to_s
      max_length = User.username_length.end - 1 - suffix.length
      attempt = "#{name[0..max_length]}#{suffix}"
      i+=1
    end
    attempt
  end

  def self.create_for_email(email, opts={})
    username = suggest_username(email)

    if SiteSetting.call_discourse_hub?
      begin
        match, available, suggestion = DiscourseHub.nickname_match?( username, email )
        username = suggestion unless match or available
      rescue => e
        Rails.logger.error e.message + "\n" + e.backtrace.join("\n")
      end
    end

    user = User.new(email: email, username: username, name: username)
    user.trust_level = opts[:trust_level] if opts[:trust_level].present?
    user.save!

    if SiteSetting.call_discourse_hub?
      begin
        DiscourseHub.register_nickname( username, email )
      rescue => e
        Rails.logger.error e.message + "\n" + e.backtrace.join("\n")
      end
    end

    user
  end

  def self.username_available?(username)
    lower = username.downcase
    !User.where(username_lower: lower).exists?
  end

  def self.username_valid?(username)
    u = User.new(username: username)
    u.username_format_validator
    !u.errors[:username].present?
  end

  def enqueue_welcome_message(message_type)
    return unless SiteSetting.send_welcome_message?
    Jobs.enqueue(:send_system_message, user_id: self.id, message_type: message_type)
  end

  def self.suggest_name(email)
    return "" unless email
    name = email.split(/[@\+]/)[0]
    name = name.sub(".", "  ")
    name.split(" ").collect{|word| word[0] = word[0].upcase; word}.join(" ")
  end

  def change_username(new_username)
    current_username = self.username
    self.username = new_username

    if SiteSetting.call_discourse_hub? and self.valid?
      begin
        DiscourseHub.change_nickname( current_username, new_username )
      rescue DiscourseHub::NicknameUnavailable
        return false
      rescue => e
        Rails.logger.error e.message + "\n" + e.backtrace.join("\n")
      end
    end

    self.save
  end

  # Use a temporary key to find this user, store it in redis with an expiry
  def temporary_key
    key = SecureRandom.hex(32)
    $redis.setex "temporary_key:#{key}", 1.week, id.to_s
    key
  end

  # Find a user by temporary key, nil if not found or key is invalid
  def self.find_by_temporary_key(key)
    user_id = $redis.get("temporary_key:#{key}")
    if user_id.present?
      User.where(id: user_id.to_i).first
    end
  end

  # tricky, we need our bus to be subscribed from the right spot
  def sync_notification_channel_position
    @unread_notifications_by_type = nil
    self.notification_channel_position = MessageBus.last_id('/notification')
  end

  def invited_by
    used_invite = invites.where("redeemed_at is not null").includes(:invited_by).first
    return nil unless used_invite.present?
    used_invite.invited_by
  end

  # Approve this user
  def approve(approved_by)
    self.approved = true
    self.approved_by = approved_by
    self.approved_at = Time.now
    enqueue_welcome_message('welcome_approved') if save
  end

  def self.email_hash(email)
    Digest::MD5.hexdigest(email.strip.downcase)
  end

  def email_hash
    User.email_hash(self.email)
  end

  def unread_notifications_by_type
    @unread_notifications_by_type ||= notifications.where("id > ? and read = false", seen_notification_id).group(:notification_type).count
  end

  def reload
    @unread_notifications_by_type = nil
    super
  end


  def unread_private_messages
    return 0 if unread_notifications_by_type.blank?
    return unread_notifications_by_type[Notification.Types[:private_message]] || 0
  end

  def unread_notifications
    result = 0
    unread_notifications_by_type.each do |k,v|
      result += v unless k == Notification.Types[:private_message]
    end
    result
  end

  def saw_notification_id(notification_id)
    User.update_all ["seen_notification_id = ?", notification_id], ["seen_notification_id < ?", notification_id]
  end

  def publish_notifications_state
    MessageBus.publish("/notification",
        {unread_notifications: self.unread_notifications,
         unread_private_messages: self.unread_private_messages},
        user_ids: [self.id] # only publish the notification to this user
      )
  end

  # A selection of people to autocomplete on @mention
  def self.mentionable_usernames
    User.select(:username).order('last_posted_at desc').limit(20)
  end

  def regular?
    (not admin?) and (not has_trust_level?(:moderator))
  end

  def password=(password)
    # special case for passwordless accounts
    unless password.blank?
      @raw_password = password
    end
  end

  # Indicate that this is NOT a passwordless account for the purposes of validation
  def password_required
    @password_required = true
  end

  def confirm_password?(password)
    return false unless self.password_hash && self.salt
    self.password_hash == hash_password(password,self.salt)
  end

  def seen?(date)
    if last_seen_at.present?
      !(last_seen_at.to_date < date)
    end
  end

  def seen_before?
    last_seen_at.present?
  end

  def has_visit_record?(date)
    user_visits.where(["visited_at =? ", date ]).first
  end

  def adding_visit_record(date)
    user_visits.create!(visited_at: date )
  end

  def update_visit_record!(date)
    if !seen_before?
      adding_visit_record(date)
      update_column(:days_visited, 1)
    end

    if !seen?(date)
      if !has_visit_record?(date)
        adding_visit_record(date)
        User.increment_counter(:days_visited, 1)
      end
    end
  end

  def update_last_seen!
    now = DateTime.now
    now_date = now.to_date
    # Only update last seen once every minute
    redis_key = "user:#{self.id}:#{now_date.to_s}"
    if $redis.setnx(redis_key, "1")
      $redis.expire(redis_key, SiteSetting.active_user_rate_limit_secs)

      update_visit_record!(now_date)

      # using update_column to avoid the AR transaction
      # Keep track of our last visit
      if seen_before? && (self.last_seen_at < (now - SiteSetting.previous_visit_timeout_hours.hours))
        previous_visit_at = last_seen_at
        update_column(:previous_visit_at, previous_visit_at )
      end
      update_column(:last_seen_at,  now )

    end

  end

  def self.avatar_template(email)
    email_hash = self.email_hash(email)
    # robohash was possibly causing caching issues
    # robohash = CGI.escape("http://robohash.org/size_") << "{size}x{size}" << CGI.escape("/#{email_hash}.png")
    "http://www.gravatar.com/avatar/#{email_hash}.png?s={size}&r=pg&d=identicon"
  end

  # return null for local avatars, a template for gravatar
  def avatar_template
    # robohash = CGI.escape("http://robohash.org/size_") << "{size}x{size}" << CGI.escape("/#{email_hash}.png")
    "http://www.gravatar.com/avatar/#{email_hash}.png?s={size}&r=pg&d=identicon"
  end


  # Updates the denormalized view counts for all users
  def self.update_view_counts

    # Update denormalized topics_entered
    exec_sql "UPDATE users SET topics_entered = x.c
             FROM
            (SELECT v.user_id,
                    COUNT(DISTINCT parent_id) AS c
             FROM views AS v
             WHERE parent_type = 'Topic'
             GROUP BY v.user_id) AS X
            WHERE x.user_id = users.id"

    # Update denormalzied posts_read_count
    exec_sql "UPDATE users SET posts_read_count = x.c
              FROM
              (SELECT pt.user_id,
                      COUNT(*) AS c
               FROM post_timings AS pt
               GROUP BY pt.user_id) AS X
               WHERE x.user_id = users.id"

  end

  # The following count methods are somewhat slow - definitely don't use them in a loop.
  # They might need to be denormialzied
  def like_count
    UserAction.where(user_id: self.id, action_type: UserAction::WAS_LIKED).count
  end

  def post_count
    posts.count
  end

  def flags_given_count
    PostAction.where(user_id: self.id, post_action_type_id: PostActionType.FlagTypes).count
  end

  def flags_received_count
    posts.includes(:post_actions).where('post_actions.post_action_type_id in (?)', PostActionType.FlagTypes).count
  end

  def private_topics_count
    topics_allowed.where(archetype: Archetype.private_message).count
  end

  def bio_excerpt
    PrettyText.excerpt(bio_cooked, 350)
  end

  def delete_all_posts!(guardian)
    raise Discourse::InvalidAccess unless guardian.can_delete_all_posts? self

    posts.order("post_number desc").each do |p|
      if p.post_number == 1
        p.topic.destroy
      else
        p.destroy
      end
    end
  end

  def is_banned?
    !banned_till.nil? && banned_till > DateTime.now
  end

  # Use this helper to determine if the user has a particular trust level.
  # Takes into account admin, etc.
  def has_trust_level?(level)
    raise "Invalid trust level #{level}" unless TrustLevel.Levels.has_key?(level)

    # Admins can do everything
    return true if admin?

    # Otherwise compare levels
    (self.trust_level || TrustLevel.Levels[:new]) >= TrustLevel.Levels[level]
  end

  def change_trust_level(level)
    raise "Invalid trust level #{level}" unless TrustLevel.Levels.has_key?(level)
    self.trust_level = TrustLevel.Levels[level]
  end

  def guardian
    Guardian.new(self)
  end

  def username_format_validator
    validator = UsernameValidator.new(username)
    unless validator.valid_format?
      validator.errors.each { |e| errors.add(:username, e) }
    end
  end

  def email_confirmed?
    email_tokens.where(email: self.email, confirmed: true).present? or email_tokens.count == 0
  end

  def treat_as_new_topic_start_date
    duration = new_topic_duration_minutes || SiteSetting.new_topic_duration_minutes 
    case duration 
    when User::NewTopicDuration::ALWAYS
      created_at
    when User::NewTopicDuration::LAST_VISIT
      previous_visit_at || created_at
    else
      duration.minutes.ago
    end 
  end

  protected

    def cook
      if self.bio_raw.present?
        self.bio_cooked = PrettyText.cook(bio_raw) if bio_raw_changed?
      else
        self.bio_cooked = nil
      end
    end

    def update_tracked_topics
      if self.auto_track_topics_after_msecs_changed?

        if auto_track_topics_after_msecs < 0

          User.exec_sql('update topic_users set notification_level = ?
                         where notifications_reason_id is null and
                           user_id = ?' , TopicUser::NotificationLevel::REGULAR , self.id)
        else

          User.exec_sql('update topic_users set notification_level = ?
                         where notifications_reason_id is null and
                           user_id = ? and
                           total_msecs_viewed < ?' , TopicUser::NotificationLevel::REGULAR , self.id, auto_track_topics_after_msecs)

          User.exec_sql('update topic_users set notification_level = ?
                         where notifications_reason_id is null and
                           user_id = ? and
                           total_msecs_viewed >= ?' , TopicUser::NotificationLevel::TRACKING , self.id, auto_track_topics_after_msecs)
        end
      end
    end


    def create_email_token
      email_tokens.create(email: self.email)
    end

    def ensure_password_is_hashed
      if @raw_password
        self.salt = SecureRandom.hex(16)
        self.password_hash = hash_password(@raw_password, salt)
      end
    end

    def hash_password(password, salt)
      PBKDF2.new(:password => password, :salt => salt, :iterations => Rails.configuration.pbkdf2_iterations).hex_string
    end

    def add_trust_level
      self.trust_level ||= SiteSetting.default_trust_level
    rescue ActiveModel::MissingAttributeError
      # Ignore it, safely - see http://www.tatvartha.com/2011/03/activerecordmissingattributeerror-missing-attribute-a-bug-or-a-features/
    end

    def update_username_lower
      self.username_lower = username.downcase
    end

    def username_validator
      username_format_validator || begin
        lower = username.downcase
        if username_changed? && User.where(username_lower: lower).exists?
          return errors.add(:username, I18n.t(:'user.username.unique'))
        end
      end
    end

    def email_validator
      if (setting = SiteSetting.email_domains_blacklist).present?
        domains = setting.gsub('.', '\.')
        regexp = Regexp.new("@(#{domains})", true)
        if self.email =~ regexp
          return errors.add(:email, I18n.t(:'user.email.not_allowed'))
        end
      end
    end

    def password_validator
      if (@raw_password and @raw_password.length < 6) or (@password_required and !@raw_password)
        return errors.add(:password, "must be 6 letters or longer")
      end
    end

end
