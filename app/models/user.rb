require_dependency 'email'
require_dependency 'email_token'
require_dependency 'trust_level'
require_dependency 'pbkdf2'
require_dependency 'summarize'

class User < ActiveRecord::Base
  attr_accessible :name, :username, :password, :email, :bio_raw, :website

  has_many :posts
  has_many :notifications
  has_many :topic_users
  has_many :topics
  has_many :user_open_ids, dependent: :destroy
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
  has_one :twitter_user_info, dependent: :destroy
  has_one :github_user_info, dependent: :destroy
  belongs_to :approved_by, class_name: 'User'

  has_many :group_users
  has_many :groups, through: :group_users
  has_many :secure_categories, through: :groups, source: :categories

  validates_presence_of :username
  validates_presence_of :email
  validates_uniqueness_of :email
  validate :username_validator
  validate :email_validator, if: :email_changed?
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

  scope :admins, ->{ where(admin: true) }
  scope :moderators, ->{ where(moderator: true) }

  module NewTopicDuration
    ALWAYS = -1
    LAST_VISIT = -2
  end

  def self.username_length
    3..15
  end

  def self.sanitize_username!(name)
    name.gsub!(/^[^A-Za-z0-9]+|[^A-Za-z0-9_]+$/, "")
    name.gsub!(/[^A-Za-z0-9_]+/, "_")
  end

  def self.pad_missing_chars_with_1s!(name)
    missing_chars = User.username_length.begin - name.length
    name << ('1' * missing_chars) if missing_chars > 0
  end

  def self.find_available_username_based_on(name)
    i = 1
    attempt = name
    until username_available?(attempt)
      suffix = i.to_s
      max_length = User.username_length.end - suffix.length - 1
      attempt = "#{name[0..max_length]}#{suffix}"
      i += 1
    end
    attempt
  end

  EMAIL = %r{([^@]+)@([^\.]+)}

  def self.suggest_username(name)
    return unless name.present?

    if name =~ EMAIL
      # When 'walter@white.com' take 'walter'
      name = Regexp.last_match[1]

      # When 'me@eviltrout.com' take 'eviltrout'
      name = Regexp.last_match[2] if ['i', 'me'].include?(name)
    end

    sanitize_username!(name)
    pad_missing_chars_with_1s!(name)

    # Trim extra length
    name = name[0..User.username_length.end-1]
    find_available_username_based_on(name)
  end

  def self.new_from_params(params)
    user = User.new
    user.name = params[:name]
    user.email = params[:email]
    user.password = params[:password]
    user.username = params[:username]
    user
  end

  def self.create_for_email(email, opts={})
    username = suggest_username(email)

    if SiteSetting.call_discourse_hub?
      begin
        match, available, suggestion = DiscourseHub.nickname_match?(username, email)
        username = suggestion unless match || available
      rescue => e
        Rails.logger.error e.message + "\n" + e.backtrace.join("\n")
      end
    end

    user = User.new(email: email, username: username, name: username)
    user.trust_level = opts[:trust_level] if opts[:trust_level].present?
    user.save!

    if SiteSetting.call_discourse_hub?
      begin
        DiscourseHub.register_nickname(username, email)
      rescue => e
        Rails.logger.error e.message + "\n" + e.backtrace.join("\n")
      end
    end

    user
  end

  def self.username_available?(username)
    lower = username.downcase
    User.where(username_lower: lower).blank?
  end

  def self.username_valid?(username)
    u = User.new(username: username)
    u.username_format_validator
    u.errors[:username].blank?
  end


  def self.suggest_name(email)
    return "" unless email
    name = email.split(/[@\+]/)[0]
    name = name.gsub(".", " ")
    name.titleize
  end

  # Find a user by temporary key, nil if not found or key is invalid
  def self.find_by_temporary_key(key)
    user_id = $redis.get("temporary_key:#{key}")
    if user_id.present?
      where(id: user_id.to_i).first
    end
  end

  def self.find_by_username_or_email(username_or_email)
    lower_user = username_or_email.downcase
    lower_email = Email.downcase(username_or_email)
    where("username_lower = :user or lower(username) = :user or email = :email or lower(name) = :user", user: lower_user, email: lower_email)
  end

  def enqueue_welcome_message(message_type)
    return unless SiteSetting.send_welcome_message?
    Jobs.enqueue(:send_system_message, user_id: id, message_type: message_type)
  end

  def change_username(new_username)
    current_username, self.username = username, new_username

    if SiteSetting.call_discourse_hub? && valid?
      begin
        DiscourseHub.change_nickname(current_username, new_username)
      rescue DiscourseHub::NicknameUnavailable
        false
      rescue => e
        Rails.logger.error e.message + "\n" + e.backtrace.join("\n")
      end
    end

    save
  end

  # Use a temporary key to find this user, store it in redis with an expiry
  def temporary_key
    key = SecureRandom.hex(32)
    $redis.setex "temporary_key:#{key}", 1.week, id.to_s
    key
  end


  # tricky, we need our bus to be subscribed from the right spot
  def sync_notification_channel_position
    @unread_notifications_by_type = nil
    self.notification_channel_position = MessageBus.last_id("/notification/#{id}")
  end

  def invited_by
    used_invite = invites.where("redeemed_at is not null").includes(:invited_by).first
    used_invite.try(:invited_by)
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
    User.email_hash(email)
  end

  def unread_notifications_by_type
    @unread_notifications_by_type ||= notifications.where("id > ? and read = false", seen_notification_id).group(:notification_type).count
  end

  def reload
    @unread_notifications_by_type = nil
    super
  end


  def unread_private_messages
    unread_notifications_by_type[Notification.types[:private_message]] || 0
  end

  def unread_notifications
    unread_notifications_by_type.except(Notification.types[:private_message]).values.sum
  end

  def saw_notification_id(notification_id)
    User.update_all ["seen_notification_id = ?", notification_id], ["seen_notification_id < ?", notification_id]
  end

  def publish_notifications_state
    MessageBus.publish("/notification/#{id}",
        { unread_notifications: unread_notifications,
          unread_private_messages: unread_private_messages },
        user_ids: [id] # only publish the notification to this user
      )
  end

  # A selection of people to autocomplete on @mention
  def self.mentionable_usernames
    User.select(:username).order('last_posted_at desc').limit(20)
  end

  def moderator?
    # this saves us from checking both, admins are always moderators
    #
    # in future we may split this out
    admin || moderator
  end

  def regular?
    !(admin? || moderator?)
  end

  def password=(password)
    # special case for passwordless accounts
    @raw_password = password unless password.blank?
  end

  # Indicate that this is NOT a passwordless account for the purposes of validation
  def password_required!
    @password_required = true
  end

  def confirm_password?(password)
    return false unless password_hash && salt
    self.password_hash == hash_password(password, salt)
  end

  def seen?(date)
    last_seen_at.to_date >= date if last_seen_at.present?
  end

  def seen_before?
    last_seen_at.present?
  end

  def has_visit_record?(date)
    user_visits.where(visited_at: date).first
  end

  def update_visit_record!(date)
    unless seen_before?
      user_visits.create!(visited_at: date)
      update_column(:days_visited, 1)
    end

    unless seen?(date) || has_visit_record?(date)
      user_visits.create!(visited_at: date)
      User.update_all('days_visited = days_visited + 1', id: self.id)
    end
  end

  def update_ip_address!(new_ip_address)
    unless ip_address == new_ip_address || new_ip_address.blank?
      update_column(:ip_address, new_ip_address)
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
        update_column(:previous_visit_at, previous_visit_at)
      end
      update_column(:last_seen_at,  now)
    end
  end

  def self.avatar_template(email)
    email_hash = self.email_hash(email)
    # robohash was possibly causing caching issues
    # robohash = CGI.escape("http://robohash.org/size_") << "{size}x{size}" << CGI.escape("/#{email_hash}.png")
    "https://www.gravatar.com/avatar/#{email_hash}.png?s={size}&r=pg&d=identicon"
  end

  # Don't pass this up to the client - it's meant for server side use
  def small_avatar_url
    "https://www.gravatar.com/avatar/#{email_hash}.png?s=200&r=pg&d=identicon"
  end

  # return null for local avatars, a template for gravatar
  def avatar_template
    User.avatar_template(email)
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
  # They might need to be denormalized
  def like_count
    UserAction.where(user_id: id, action_type: UserAction::WAS_LIKED).count
  end

  def post_count
    posts.count
  end

  def flags_given_count
    PostAction.where(user_id: id, post_action_type_id: PostActionType.flag_types.values).count
  end

  def flags_received_count
    posts.includes(:post_actions).where('post_actions.post_action_type_id' => PostActionType.flag_types.values).count
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
        # TODO: But the post is not destroyed. Why?
      else
        # TODO: This should be using the PostDestroyer!
        p.destroy
      end
    end
  end

  def is_banned?
    banned_till && banned_till > DateTime.now
  end

  # Use this helper to determine if the user has a particular trust level.
  # Takes into account admin, etc.
  def has_trust_level?(level)
    raise "Invalid trust level #{level}" unless TrustLevel.valid_level?(level)
    admin? || moderator? || TrustLevel.compare(trust_level, level)
  end

  # a touch faster than automatic
  def admin?
    admin
  end

  def change_trust_level(level)
    raise "Invalid trust level #{level}" unless TrustLevel.valid_level?(level)
    self.trust_level = TrustLevel.levels[level]
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
    email_tokens.where(email: email, confirmed: true).present? || email_tokens.empty?
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

  MAX_TIME_READ_DIFF = 100
  # attempt to add total read time to user based on previous time this was called
  def update_time_read!
    last_seen_key = "user-last-seen:#{id}"
    last_seen = $redis.get(last_seen_key)
    if last_seen.present?
      diff = (Time.now.to_f - last_seen.to_f).round
      if diff > 0 && diff < MAX_TIME_READ_DIFF
        User.update_all ["time_read = time_read + ?", diff], id: id, time_read: time_read
      end
    end
    $redis.set(last_seen_key, Time.now.to_f)
  end

  def readable_name
    return "#{name} (#{username})" if name.present? && name != username
    username
  end

  def bio_summary
    return nil unless bio_cooked.present?
    Summarize.new(bio_cooked).summary
  end

  def self.count_by_signup_date(sinceDaysAgo=30)
    where('created_at > ?', sinceDaysAgo.days.ago).group('date(created_at)').order('date(created_at)').count
  end

  def self.counts_by_trust_level
    group('trust_level').count
  end

  def update_topic_reply_count
    self.topic_reply_count =
      Topic
        .where(['id in (
              SELECT topic_id FROM posts p
              JOIN topics t2 ON t2.id = p.topic_id
              WHERE p.deleted_at IS NULL AND
                t2.user_id <> p.user_id AND
                p.user_id = ?
              )', self.id])
        .count
  end

  def secure_category_ids
    cats = self.moderator? ? Category.select(:id).where(:secure, true) : secure_categories.select('categories.id')
    cats.map{|c| c.id}
  end

  protected

    def cook
      if bio_raw.present?
        self.bio_cooked = PrettyText.cook(bio_raw) if bio_raw_changed?
      else
        self.bio_cooked = nil
      end
    end

    def update_tracked_topics
      return unless auto_track_topics_after_msecs_changed?

      where_conditions = {notifications_reason_id: nil, user_id: id}
      if auto_track_topics_after_msecs < 0
        TopicUser.update_all({notification_level: TopicUser.notification_levels[:regular]}, where_conditions)
      else
        TopicUser.update_all(["notification_level = CASE WHEN total_msecs_viewed < ? THEN ? ELSE ? END",
                              auto_track_topics_after_msecs, TopicUser.notification_levels[:regular], TopicUser.notification_levels[:tracking]], where_conditions)
      end
    end


    def create_email_token
      email_tokens.create(email: email)
    end

    def ensure_password_is_hashed
      if @raw_password
        self.salt = SecureRandom.hex(16)
        self.password_hash = hash_password(@raw_password, salt)
      end
    end

    def hash_password(password, salt)
      Pbkdf2.hash_password(password, salt, Rails.configuration.pbkdf2_iterations)
    end

    def add_trust_level
      # there is a possiblity we did not load trust level column, skip it
      return unless has_attribute? :trust_level
      self.trust_level ||= SiteSetting.default_trust_level
    end

    def update_username_lower
      self.username_lower = username.downcase
    end

    def username_validator
      username_format_validator || begin
        lower = username.downcase
        if username_changed? && User.where(username_lower: lower).exists?
          errors.add(:username, I18n.t(:'user.username.unique'))
        end
      end
    end

    def email_validator
      if (setting = SiteSetting.email_domains_whitelist).present?
        unless email_in_restriction_setting?(setting)
          errors.add(:email, I18n.t(:'user.email.not_allowed'))
        end
      elsif (setting = SiteSetting.email_domains_blacklist).present?
        if email_in_restriction_setting?(setting)
          errors.add(:email, I18n.t(:'user.email.not_allowed'))
        end
      end
    end

    def email_in_restriction_setting?(setting)
      domains = setting.gsub('.', '\.')
      regexp = Regexp.new("@(#{domains})", true)
      self.email =~ regexp
    end

    def password_validator
      if (@raw_password && @raw_password.length < 6) || (@password_required && !@raw_password)
        errors.add(:password, "must be 6 letters or longer")
      end
    end


end
