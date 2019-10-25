# frozen_string_literal: true

class User < ActiveRecord::Base
  include Searchable
  include Roleable
  include HasCustomFields
  include SecondFactorManager
  include HasDestroyedWebHook

  has_many :posts
  has_many :notifications, dependent: :delete_all
  has_many :topic_users, dependent: :delete_all
  has_many :category_users, dependent: :destroy
  has_many :tag_users, dependent: :destroy
  has_many :user_api_keys, dependent: :destroy
  has_many :topics
  has_many :user_open_ids, dependent: :destroy

  # dependent deleting handled via before_destroy
  has_many :user_actions
  has_many :post_actions

  has_many :user_badges, -> { where('user_badges.badge_id IN (SELECT id FROM badges WHERE enabled)') }, dependent: :destroy
  has_many :badges, through: :user_badges
  has_many :email_logs, dependent: :delete_all
  has_many :incoming_emails, dependent: :delete_all
  has_many :post_timings
  has_many :topic_allowed_users, dependent: :destroy
  has_many :topics_allowed, through: :topic_allowed_users, source: :topic
  has_many :email_tokens, dependent: :destroy
  has_many :user_visits, dependent: :destroy
  has_many :invites, dependent: :destroy
  has_many :topic_links, dependent: :destroy
  has_many :uploads
  has_many :user_warnings
  has_many :user_archived_messages, dependent: :destroy
  has_many :email_change_requests, dependent: :destroy

  # see before_destroy
  has_many :directory_items
  has_many :user_auth_tokens, dependent: :destroy
  has_many :user_auth_token_logs, dependent: :destroy

  has_many :group_users, dependent: :destroy
  has_many :groups, through: :group_users
  has_many :group_requests, dependent: :destroy
  has_many :secure_categories, through: :groups, source: :categories

  has_many :user_uploads, dependent: :destroy
  has_many :user_emails, dependent: :destroy

  has_one :primary_email, -> { where(primary: true)  }, class_name: 'UserEmail', dependent: :destroy

  has_one :user_option, dependent: :destroy
  has_one :user_avatar, dependent: :destroy
  has_many :user_associated_accounts, dependent: :destroy
  has_one :github_user_info, dependent: :destroy
  has_many :oauth2_user_infos, dependent: :destroy
  has_one :instagram_user_info, dependent: :destroy
  has_many :user_second_factors, dependent: :destroy

  has_many :totps, -> {
    where(method: UserSecondFactor.methods[:totp], enabled: true)
  }, class_name: "UserSecondFactor"

  has_many :security_keys, -> {
    where(enabled: true)
  }, class_name: "UserSecurityKey"

  has_one :anonymous_user_master, class_name: 'AnonymousUser'
  has_one :anonymous_user_shadow, ->(record) { where(active: true) }, foreign_key: :master_user_id, class_name: 'AnonymousUser'

  has_one :master_user, through: :anonymous_user_master
  has_one :shadow_user, through: :anonymous_user_shadow, source: :user

  has_one :user_stat, dependent: :destroy
  has_one :user_profile, dependent: :destroy, inverse_of: :user
  has_one :profile_background_upload, through: :user_profile
  has_one :card_background_upload, through: :user_profile
  has_one :single_sign_on_record, dependent: :destroy
  belongs_to :approved_by, class_name: 'User'
  belongs_to :primary_group, class_name: 'Group'

  has_many :muted_user_records, class_name: 'MutedUser'
  has_many :muted_users, through: :muted_user_records

  has_one :api_key, dependent: :destroy

  has_many :push_subscriptions, dependent: :destroy

  belongs_to :uploaded_avatar, class_name: 'Upload'

  has_many :acting_group_histories, dependent: :destroy, foreign_key: :acting_user_id, class_name: 'GroupHistory'
  has_many :targeted_group_histories, dependent: :destroy, foreign_key: :target_user_id, class_name: 'GroupHistory'

  has_many :reviewable_scores, dependent: :destroy

  delegate :last_sent_email_address, to: :email_logs

  validates_presence_of :username
  validate :username_validator, if: :will_save_change_to_username?
  validate :password_validator
  validate :name_validator, if: :will_save_change_to_name?
  validates :name, user_full_name: true, if: :will_save_change_to_name?, length: { maximum: 255 }
  validates :ip_address, allowed_ip_address: { on: :create, message: :signup_not_allowed }
  validates :primary_email, presence: true
  validates_associated :primary_email, message: -> (_, user_email) { user_email[:value]&.errors[:email]&.first }

  after_initialize :add_trust_level

  before_validation :set_skip_validate_email

  after_create :create_email_token
  after_create :create_user_stat
  after_create :create_user_option
  after_create :create_user_profile
  after_create :set_random_avatar
  after_create :ensure_in_trust_level_group
  after_create :set_default_categories_preferences

  after_update :trigger_user_updated_event, if: :saved_change_to_uploaded_avatar_id?
  after_update :trigger_user_automatic_group_refresh, if: :saved_change_to_staged?

  before_save :update_usernames
  before_save :ensure_password_is_hashed
  before_save :match_title_to_primary_group_changes
  before_save :check_if_title_is_badged_granted

  after_save :expire_tokens_if_password_changed
  after_save :clear_global_notice_if_needed
  after_save :refresh_avatar
  after_save :badge_grant
  after_save :expire_old_email_tokens
  after_save :index_search
  after_save :check_site_contact_username

  after_commit :trigger_user_created_event, on: :create
  after_commit :trigger_user_destroyed_event, on: :destroy

  before_destroy do
    # These tables don't have primary keys, so destroying them with activerecord is tricky:
    PostTiming.where(user_id: self.id).delete_all
    TopicViewItem.where(user_id: self.id).delete_all
    UserAction.where('user_id = :user_id OR target_user_id = :user_id OR acting_user_id = :user_id', user_id: self.id).delete_all

    # we need to bypass the default scope here, which appears not bypassed for :delete_all
    # however :destroy it is bypassed
    PostAction.with_deleted.where(user_id: self.id).delete_all

    # This is a perf optimisation to ensure we hit the index
    # without this we need to scan a much larger number of rows
    DirectoryItem.where(user_id: self.id)
      .where('period_type in (?)', DirectoryItem.period_types.values)
      .delete_all
  end

  # Skip validating email, for example from a particular auth provider plugin
  attr_accessor :skip_email_validation

  # Whether we need to be sending a system message after creation
  attr_accessor :send_welcome_message

  # This is just used to pass some information into the serializer
  attr_accessor :notification_channel_position

  # set to true to optimize creation and save for imports
  attr_accessor :import_mode

  scope :with_email, ->(email) do
    joins(:user_emails).where("lower(user_emails.email) IN (?)", email)
  end

  scope :human_users, -> { where('users.id > 0') }

  # excluding fake users like the system user or anonymous users
  scope :real, -> { human_users.where('NOT EXISTS(
                     SELECT 1
                     FROM anonymous_users a
                     WHERE a.user_id = users.id
                  )') }

  # TODO-PERF: There is no indexes on any of these
  # and NotifyMailingListSubscribers does a select-all-and-loop
  # may want to create an index on (active, silence, suspended_till)?
  scope :silenced, -> { where("silenced_till IS NOT NULL AND silenced_till > ?", Time.zone.now) }
  scope :not_silenced, -> { where("silenced_till IS NULL OR silenced_till <= ?", Time.zone.now) }
  scope :suspended, -> { where('suspended_till IS NOT NULL AND suspended_till > ?', Time.zone.now) }
  scope :not_suspended, -> { where('suspended_till IS NULL OR suspended_till <= ?', Time.zone.now) }
  scope :activated, -> { where(active: true) }

  scope :filter_by_username, ->(filter) do
    if filter.is_a?(Array)
      where('username_lower ~* ?', "(#{filter.join('|')})")
    else
      where('username_lower ILIKE ?', "%#{filter}%")
    end
  end

  scope :filter_by_username_or_email, ->(filter) do
    if filter =~ /.+@.+/
      # probably an email so try the bypass
      if user_id = UserEmail.where("lower(email) = ?", filter.downcase).pluck_first(:user_id)
        return where('users.id = ?', user_id)
      end
    end

    users = joins(:primary_email)

    if filter.is_a?(Array)
      users.where(
        'username_lower ~* :filter OR lower(user_emails.email) SIMILAR TO :filter',
        filter: "(#{filter.join('|')})"
      )
    else
      users.where(
        'username_lower ILIKE :filter OR lower(user_emails.email) ILIKE :filter',
        filter: "%#{filter}%"
      )
    end
  end

  module NewTopicDuration
    ALWAYS = -1
    LAST_VISIT = -2
  end

  MAX_SELF_DELETE_POST_COUNT ||= 1
  MAX_STAFF_DELETE_POST_COUNT ||= 5

  def self.max_password_length
    200
  end

  def self.username_length
    SiteSetting.min_username_length.to_i..SiteSetting.max_username_length.to_i
  end

  def self.normalize_username(username)
    username.unicode_normalize.downcase if username.present?
  end

  def self.username_available?(username, email = nil, allow_reserved_username: false)
    lower = normalize_username(username)
    return false if !allow_reserved_username && reserved_username?(lower)
    return true  if !username_exists?(lower)

    # staged users can use the same username since they will take over the account
    email.present? && User.joins(:user_emails).exists?(staged: true, username_lower: lower, user_emails: { primary: true, email: email })
  end

  def self.reserved_username?(username)
    username = normalize_username(username)

    SiteSetting.reserved_usernames.unicode_normalize.split("|").any? do |reserved|
      username.match?(/^#{Regexp.escape(reserved).gsub('\*', '.*')}$/)
    end
  end

  def self.plugin_editable_user_custom_fields
    @plugin_editable_user_custom_fields ||= {}
  end

  def self.plugin_staff_editable_user_custom_fields
    @plugin_staff_editable_user_custom_fields ||= {}
  end

  def self.register_plugin_editable_user_custom_field(custom_field_name, plugin, staff_only: false)
    if staff_only
      plugin_staff_editable_user_custom_fields[custom_field_name] = plugin
    else
      plugin_editable_user_custom_fields[custom_field_name] = plugin
    end
  end

  def self.editable_user_custom_fields(by_staff: false)
    fields = []

    plugin_editable_user_custom_fields.each do |k, v|
      fields << k if v.enabled?
    end

    if by_staff
      plugin_staff_editable_user_custom_fields.each do |k, v|
        fields << k if v.enabled?
      end
    end

    fields.uniq
  end

  def self.plugin_staff_user_custom_fields
    @plugin_staff_user_custom_fields ||= {}
  end

  def self.register_plugin_staff_custom_field(custom_field_name, plugin)
    plugin_staff_user_custom_fields[custom_field_name] = plugin
  end

  def self.plugin_public_user_custom_fields
    @plugin_public_user_custom_fields ||= {}
  end

  def self.register_plugin_public_custom_field(custom_field_name, plugin)
    plugin_public_user_custom_fields[custom_field_name] = plugin
  end

  def self.whitelisted_user_custom_fields(guardian)
    fields = []

    plugin_public_user_custom_fields.each do |k, v|
      fields << k if v.enabled?
    end

    if SiteSetting.public_user_custom_fields.present?
      fields += SiteSetting.public_user_custom_fields.split('|')
    end

    if guardian.is_staff?
      if SiteSetting.staff_user_custom_fields.present?
        fields += SiteSetting.staff_user_custom_fields.split('|')
      end
      plugin_staff_user_custom_fields.each do |k, v|
        fields << k if v.enabled?
      end
    end

    fields.uniq
  end

  def human?
    self.id > 0
  end

  def bot?
    !self.human?
  end

  def effective_locale
    if SiteSetting.allow_user_locale && self.locale.present?
      self.locale
    else
      SiteSetting.default_locale
    end
  end

  EMAIL = %r{([^@]+)@([^\.]+)}
  FROM_STAGED = "from_staged".freeze

  def self.new_from_params(params)
    user = User.new
    user.name = params[:name]
    user.email = params[:email]
    user.password = params[:password]
    user.username = params[:username]
    user
  end

  def unstage
    if self.staged
      self.staged = false
      self.custom_fields[FROM_STAGED] = true
      self.notifications.destroy_all
      DiscourseEvent.trigger(:user_unstaged, self)
    end
  end

  def self.unstage(params)
    if user = User.where(staged: true).with_email(params[:email].strip.downcase).first
      params.each { |k, v| user.public_send("#{k}=", v) }
      user.active = false
      user.unstage
    end
    user
  end

  def self.suggest_name(string)
    return "" if string.blank?
    (string[/\A[^@]+/].presence || string[/[^@]+\z/]).tr(".", " ").titleize
  end

  def self.find_by_username_or_email(username_or_email)
    if username_or_email.include?('@')
      find_by_email(username_or_email)
    else
      find_by_username(username_or_email)
    end
  end

  def self.find_by_email(email)
    self.with_email(Email.downcase(email)).first
  end

  def self.find_by_username(username)
    find_by(username_lower: normalize_username(username))
  end

  def group_granted_trust_level
    GroupUser
      .where(user_id: id)
      .includes(:group)
      .maximum("groups.grant_trust_level")
  end

  def visible_groups
    groups.visible_groups(self)
  end

  def enqueue_welcome_message(message_type)
    return unless SiteSetting.send_welcome_message?
    Jobs.enqueue(:send_system_message, user_id: id, message_type: message_type)
  end

  def enqueue_member_welcome_message
    return unless SiteSetting.send_tl1_welcome_message?
    Jobs.enqueue(:send_system_message, user_id: id, message_type: "welcome_tl1_user")
  end

  def enqueue_welcome_moderator_message
    return unless moderator
    Jobs.enqueue(:send_system_message, user_id: id, message_type: 'welcome_moderator')
  end

  def change_username(new_username, actor = nil)
    UsernameChanger.change(self, new_username, actor)
  end

  def created_topic_count
    stat = user_stat || create_user_stat
    stat.topic_count
  end

  alias_method :topic_count, :created_topic_count

  # tricky, we need our bus to be subscribed from the right spot
  def sync_notification_channel_position
    @unread_notifications_by_type = nil
    self.notification_channel_position = MessageBus.last_id("/notification/#{id}")
  end

  def invited_by
    used_invite = invites.where("redeemed_at is not null").includes(:invited_by).first
    used_invite.try(:invited_by)
  end

  def should_validate_email_address?
    !skip_email_validation && !staged?
  end

  def self.email_hash(email)
    Digest::MD5.hexdigest(email.strip.downcase)
  end

  def email_hash
    User.email_hash(email)
  end

  def reload
    @unread_notifications = nil
    @unread_total_notifications = nil
    @unread_pms = nil
    @user_fields = nil
    super
  end

  def unread_notifications_of_type(notification_type)
    # perf critical, much more efficient than AR
    sql = <<~SQL
        SELECT COUNT(*)
          FROM notifications n
     LEFT JOIN topics t ON t.id = n.topic_id
         WHERE t.deleted_at IS NULL
           AND n.notification_type = :type
           AND n.user_id = :user_id
           AND NOT read
    SQL

    # to avoid coalesce we do to_i
    DB.query_single(sql, user_id: id, type: notification_type)[0].to_i
  end

  def unread_private_messages
    @unread_pms ||= unread_notifications_of_type(Notification.types[:private_message])
  end

  # PERF: This safeguard is in place to avoid situations where
  # a user with enormous amounts of unread data can issue extremely
  # expensive queries
  MAX_UNREAD_NOTIFICATIONS = 99

  def self.max_unread_notifications
    @max_unread_notifications ||= MAX_UNREAD_NOTIFICATIONS
  end

  def self.max_unread_notifications=(val)
    @max_unread_notifications = val
  end

  def unread_notifications
    @unread_notifications ||= begin
      # perf critical, much more efficient than AR
      sql = <<~SQL
        SELECT COUNT(*) FROM (
          SELECT 1 FROM
          notifications n
          LEFT JOIN topics t ON t.id = n.topic_id
           WHERE t.deleted_at IS NULL AND
            n.notification_type <> :pm AND
            n.user_id = :user_id AND
            n.id > :seen_notification_id AND
            NOT read
          LIMIT :limit
        ) AS X
      SQL

      DB.query_single(sql,
        user_id: id,
        seen_notification_id: seen_notification_id,
        pm: Notification.types[:private_message],
        limit: User.max_unread_notifications
    )[0].to_i
    end
  end

  def total_unread_notifications
    @unread_total_notifications ||= notifications.where("read = false").count
  end

  def saw_notification_id(notification_id)
    if seen_notification_id.to_i < notification_id.to_i
      update_columns(seen_notification_id: notification_id.to_i)
      true
    else
      false
    end
  end

  TRACK_FIRST_NOTIFICATION_READ_DURATION = 1.week.to_i

  def read_first_notification?
    if (trust_level > TrustLevel[1] ||
        (first_seen_at.present? && first_seen_at < TRACK_FIRST_NOTIFICATION_READ_DURATION.seconds.ago))

      return true
    end

    self.seen_notification_id == 0 ? false : true
  end

  def publish_notifications_state
    # publish last notification json with the message so we can apply an update
    notification = notifications.visible.order('notifications.created_at desc').first
    json = NotificationSerializer.new(notification).as_json if notification

    sql = (<<~SQL).freeze
       SELECT * FROM (
         SELECT n.id, n.read FROM notifications n
         LEFT JOIN topics t ON n.topic_id = t.id
         WHERE
          t.deleted_at IS NULL AND
          n.notification_type = :type AND
          n.user_id = :user_id AND
          NOT read
        ORDER BY n.id DESC
        LIMIT 20
      ) AS x
      UNION ALL
      SELECT * FROM (
       SELECT n.id, n.read FROM notifications n
       LEFT JOIN topics t ON n.topic_id = t.id
       WHERE
        t.deleted_at IS NULL AND
        (n.notification_type <> :type OR read) AND
        n.user_id = :user_id
       ORDER BY n.id DESC
       LIMIT 20
      ) AS y
    SQL

    recent = DB.query(sql,
      user_id: id,
      type: Notification.types[:private_message]
    ).map! do |r|
      [r.id, r.read]
    end

    payload = {
      unread_notifications: unread_notifications,
      unread_private_messages: unread_private_messages,
      read_first_notification: read_first_notification?,
      last_notification: json,
      recent: recent,
      seen_notification_id: seen_notification_id,
    }

    MessageBus.publish("/notification/#{id}", payload, user_ids: [id])
  end

  # A selection of people to autocomplete on @mention
  def self.mentionable_usernames
    User.select(:username).order('last_posted_at desc').limit(20)
  end

  def password=(password)
    # special case for passwordless accounts
    unless password.blank?
      @raw_password = password
    end
  end

  def password
    '' # so that validator doesn't complain that a password attribute doesn't exist
  end

  # Indicate that this is NOT a passwordless account for the purposes of validation
  def password_required!
    @password_required = true
  end

  def password_required?
    !!@password_required
  end

  def password_validation_required?
    password_required? || @raw_password.present?
  end

  def has_password?
    password_hash.present?
  end

  def password_validator
    PasswordValidator.new(attributes: :password).validate_each(self, :password, @raw_password)
  end

  def confirm_password?(password)
    return false unless password_hash && salt
    self.password_hash == hash_password(password, salt)
  end

  def new_user_posting_on_first_day?
    !staff? &&
    trust_level < TrustLevel[2] &&
    (trust_level == TrustLevel[0] || self.first_post_created_at.nil? || self.first_post_created_at >= 24.hours.ago)
  end

  def new_user?
    (created_at >= 24.hours.ago || trust_level == TrustLevel[0]) &&
      trust_level < TrustLevel[2] &&
      !staff?
  end

  def seen_before?
    last_seen_at.present?
  end

  def create_visit_record!(date, opts = {})
    user_stat.update_column(:days_visited, user_stat.days_visited + 1)
    user_visits.create!(visited_at: date, posts_read: opts[:posts_read] || 0, mobile: opts[:mobile] || false)
  end

  def visit_record_for(date)
    user_visits.find_by(visited_at: date)
  end

  def update_visit_record!(date)
    create_visit_record!(date) unless visit_record_for(date)
  end

  def update_posts_read!(num_posts, opts = {})
    now = opts[:at] || Time.zone.now
    _retry = opts[:retry] || false

    if user_visit = visit_record_for(now.to_date)
      user_visit.posts_read += num_posts
      user_visit.mobile = true if opts[:mobile]
      user_visit.save
      user_visit
    else
      begin
        create_visit_record!(now.to_date, posts_read: num_posts, mobile: opts.fetch(:mobile, false))
      rescue ActiveRecord::RecordNotUnique
        if !_retry
          update_posts_read!(num_posts, opts.merge(retry: true))
        else
          raise
        end
      end
    end
  end

  def update_ip_address!(new_ip_address)
    unless ip_address == new_ip_address || new_ip_address.blank?
      update_column(:ip_address, new_ip_address)
    end
  end

  def update_last_seen!(now = Time.zone.now)
    now_date = now.to_date
    # Only update last seen once every minute
    redis_key = "user:#{id}:#{now_date}"
    return unless $redis.setnx(redis_key, "1")

    $redis.expire(redis_key, SiteSetting.active_user_rate_limit_secs)
    update_previous_visit(now)
    # using update_column to avoid the AR transaction
    update_column(:last_seen_at, now)
    update_column(:first_seen_at, now) unless self.first_seen_at

    DiscourseEvent.trigger(:user_seen, self)
  end

  def self.gravatar_template(email)
    "//www.gravatar.com/avatar/#{self.email_hash(email)}.png?s={size}&r=pg&d=identicon"
  end

  # Don't pass this up to the client - it's meant for server side use
  # This is used in
  #   - self oneboxes in open graph data
  #   - emails
  def small_avatar_url
    avatar_template_url.gsub("{size}", "45")
  end

  def avatar_template_url
    UrlHelper.schemaless UrlHelper.absolute avatar_template
  end

  def self.username_hash(username)
    username.each_char.reduce(0) do |result, char|
      [((result << 5) - result) + char.ord].pack('L').unpack('l').first
    end.abs
  end

  def self.default_template(username)
    if SiteSetting.default_avatars.present?
      urls = SiteSetting.default_avatars.split("\n")
      return urls[username_hash(username) % urls.size] if urls.present?
    end

    system_avatar_template(username)
  end

  def self.avatar_template(username, uploaded_avatar_id)
    username ||= ""
    return default_template(username) if !uploaded_avatar_id
    hostname = RailsMultisite::ConnectionManagement.current_hostname
    UserAvatar.local_avatar_template(hostname, username.downcase, uploaded_avatar_id)
  end

  def self.system_avatar_template(username)
    normalized_username = normalize_username(username)

    # TODO it may be worth caching this in a distributed cache, should be benched
    if SiteSetting.external_system_avatars_enabled
      url = SiteSetting.external_system_avatars_url.dup
      url = +"#{Discourse::base_uri}#{url}" unless url =~ /^https?:\/\//
      url.gsub! "{color}", letter_avatar_color(normalized_username)
      url.gsub! "{username}", CGI.escape(username)
      url.gsub! "{first_letter}", CGI.escape(normalized_username.grapheme_clusters.first)
      url.gsub! "{hostname}", Discourse.current_hostname
      url
    else
      "#{Discourse.base_uri}/letter_avatar/#{normalized_username}/{size}/#{LetterAvatar.version}.png"
    end
  end

  def self.letter_avatar_color(username)
    username ||= ""
    if SiteSetting.restrict_letter_avatar_colors.present?
      hex_length = 6
      colors = SiteSetting.restrict_letter_avatar_colors
      length = colors.count("|") + 1
      num = color_index(username, length)
      index = (num * hex_length) + num
      colors[index, hex_length]
    else
      color = LetterAvatar::COLORS[color_index(username, LetterAvatar::COLORS.length)]
      color.map { |c| c.to_s(16).rjust(2, '0') }.join
    end
  end

  def self.color_index(username, length)
    Digest::MD5.hexdigest(username)[0...15].to_i(16) % length
  end

  def avatar_template
    self.class.avatar_template(username, uploaded_avatar_id)
  end

  # The following count methods are somewhat slow - definitely don't use them in a loop.
  # They might need to be denormalized
  def like_count
    UserAction.where(user_id: id, action_type: UserAction::WAS_LIKED).count
  end

  def like_given_count
    UserAction.where(user_id: id, action_type: UserAction::LIKE).count
  end

  def post_count
    stat = user_stat || create_user_stat
    stat.post_count
  end

  def flags_given_count
    PostAction.where(user_id: id, post_action_type_id: PostActionType.flag_types_without_custom.values).count
  end

  def warnings_received_count
    user_warnings.count
  end

  def flags_received_count
    posts.includes(:post_actions).where('post_actions.post_action_type_id' => PostActionType.flag_types_without_custom.values).count
  end

  def private_topics_count
    topics_allowed.where(archetype: Archetype.private_message).count
  end

  def posted_too_much_in_topic?(topic_id)
    # Does not apply to staff and non-new members...
    return false if staff? || (trust_level != TrustLevel[0])
    # ... your own topics or in private messages
    topic = Topic.where(id: topic_id).first
    return false if topic.try(:private_message?) || (topic.try(:user_id) == self.id)

    last_action_in_topic = UserAction.last_action_in_topic(id, topic_id)
    since_reply = Post.where(user_id: id, topic_id: topic_id)
    since_reply = since_reply.where('id > ?', last_action_in_topic) if last_action_in_topic

    (since_reply.count >= SiteSetting.newuser_max_replies_per_topic)
  end

  def delete_posts_in_batches(guardian, batch_size = 20)
    raise Discourse::InvalidAccess unless guardian.can_delete_all_posts? self

    Reviewable.where(created_by_id: id).delete_all

    posts.order("post_number desc").limit(batch_size).each do |p|
      PostDestroyer.new(guardian.user, p).destroy
    end
  end

  def suspended?
    !!(suspended_till && suspended_till > Time.zone.now)
  end

  def silenced?
    !!(silenced_till && silenced_till > Time.zone.now)
  end

  def silenced_record
    UserHistory.for(self, :silence_user).order('id DESC').first
  end

  def silence_reason
    silenced_record.try(:details) if silenced?
  end

  def silenced_at
    silenced_record.try(:created_at) if silenced?
  end

  def suspend_record
    UserHistory.for(self, :suspend_user).order('id DESC').first
  end

  def full_suspend_reason
    return suspend_record.try(:details) if suspended?
  end

  def suspend_reason
    if details = full_suspend_reason
      return details.split("\n")[0]
    end

    nil
  end

  # Use this helper to determine if the user has a particular trust level.
  # Takes into account admin, etc.
  def has_trust_level?(level)
    unless TrustLevel.valid?(level)
      raise InvalidTrustLevel.new("Invalid trust level #{level}")
    end

    admin? || moderator? || staged? || TrustLevel.compare(trust_level, level)
  end

  # a touch faster than automatic
  def admin?
    admin
  end

  def guardian
    Guardian.new(self)
  end

  def username_format_validator
    UsernameValidator.perform_validation(self, 'username')
  end

  def email_confirmed?
    email_tokens.where(email: email, confirmed: true).present? ||
    email_tokens.empty? ||
    single_sign_on_record&.external_email == email
  end

  def activate
    if email_token = self.email_tokens.active.where(email: self.email).first
      user = EmailToken.confirm(email_token.token, skip_reviewable: true)
    end
    self.update!(active: true)
    create_reviewable
  end

  def deactivate(performed_by)
    self.update!(active: false)

    if reviewable = ReviewableUser.pending.find_by(target: self)
      reviewable.perform(performed_by, :reject_user_delete)
    end
  end

  def change_trust_level!(level, opts = nil)
    Promotion.new(self).change_trust_level!(level, opts)
  end

  def readable_name
    name.present? && name != username ? "#{name} (#{username})" : username
  end

  def badge_count
    user_badges.select('distinct badge_id').count
  end

  def featured_user_badges(limit = 3)
    tl_badge_ids = Badge.trust_level_badge_ids

    query = user_badges
      .group(:badge_id)
      .select(UserBadge.attribute_names.map { |x| "MAX(user_badges.#{x}) AS #{x}" },
                      'COUNT(*) AS "count"',
                      'MAX(badges.badge_type_id) AS badges_badge_type_id',
                      'MAX(badges.grant_count) AS badges_grant_count')
      .joins(:badge)
      .order('badges_badge_type_id ASC, badges_grant_count ASC, badge_id DESC')
      .includes(:user, :granted_by, { badge: :badge_type }, post: :topic)

    tl_badge = query.where("user_badges.badge_id IN (:tl_badge_ids)",
                           tl_badge_ids: tl_badge_ids)
      .limit(1)

    other_badges = query.where("user_badges.badge_id NOT IN (:tl_badge_ids)",
                               tl_badge_ids: tl_badge_ids)
      .limit(limit)

    (tl_badge + other_badges).take(limit)
  end

  def self.count_by_signup_date(start_date = nil, end_date = nil, group_id = nil)
    result = self

    if start_date && end_date
      result = result.group("date(users.created_at)")
      result = result.where("users.created_at >= ? AND users.created_at <= ?", start_date, end_date)
      result = result.order("date(users.created_at)")
    end

    if group_id
      result = result.joins("INNER JOIN group_users ON group_users.user_id = users.id")
      result = result.where("group_users.group_id = ?", group_id)
    end

    result.count
  end

  def self.count_by_first_post(start_date = nil, end_date = nil)
    result = joins('INNER JOIN user_stats AS us ON us.user_id = users.id')

    if start_date && end_date
      result = result.group("date(us.first_post_created_at)")
      result = result.where("us.first_post_created_at > ? AND us.first_post_created_at < ?", start_date, end_date)
      result = result.order("date(us.first_post_created_at)")
    end

    result.count
  end

  def secure_category_ids
    cats = self.admin? ? Category.unscoped.where(read_restricted: true) : secure_categories.references(:categories)
    cats.pluck('categories.id').sort
  end

  def topic_create_allowed_category_ids
    Category.topic_create_allowed(self.id).select(:id)
  end

  # Flag all posts from a user as spam
  def flag_linked_posts_as_spam
    results = []

    disagreed_flag_post_ids = PostAction.where(post_action_type_id: PostActionType.types[:spam])
      .where.not(disagreed_at: nil)
      .pluck(:post_id)

    topic_links.includes(:post)
      .where.not(post_id: disagreed_flag_post_ids)
      .each do |tl|

      message = I18n.t(
        'flag_reason.spam_hosts',
        base_path: Discourse.base_path,
        locale: SiteSetting.default_locale
      )
      results << PostActionCreator.create(Discourse.system_user, tl.post, :spam, message: message)
    end

    results
  end

  def has_uploaded_avatar
    uploaded_avatar.present?
  end

  def generate_api_key(created_by)
    if api_key.present?
      api_key.regenerate!(created_by)
      api_key
    else
      ApiKey.create!(user: self, key: SecureRandom.hex(32), created_by: created_by)
    end
  end

  def revoke_api_key
    ApiKey.where(user_id: self.id).delete_all
  end

  def find_email
    last_sent_email_address.present? && EmailValidator.email_regex =~ last_sent_email_address ? last_sent_email_address : email
  end

  def tl3_requirements
    @lq ||= TrustLevel3Requirements.new(self)
  end

  def on_tl3_grace_period?
    return true if SiteSetting.tl3_promotion_min_duration.to_i.days.ago.year < 2013

    UserHistory.for(self, :auto_trust_level_change)
      .where('created_at >= ?', SiteSetting.tl3_promotion_min_duration.to_i.days.ago)
      .where(previous_value: TrustLevel[2].to_s)
      .where(new_value: TrustLevel[3].to_s)
      .exists?
  end

  def refresh_avatar
    return if @import_mode

    avatar = user_avatar || create_user_avatar

    if SiteSetting.automatically_download_gravatars? && !avatar.last_gravatar_download_attempt
      Jobs.cancel_scheduled_job(:update_gravatar, user_id: self.id, avatar_id: avatar.id)
      Jobs.enqueue_in(1.second, :update_gravatar, user_id: self.id, avatar_id: avatar.id)
    end

    # mark all the user's quoted posts as "needing a rebake"
    Post.rebake_all_quoted_posts(self.id) if self.will_save_change_to_uploaded_avatar_id?
  end

  def first_post_created_at
    user_stat.try(:first_post_created_at)
  end

  def associated_accounts
    result = []

    Discourse.authenticators.each do |authenticator|
      account_description = authenticator.description_for_user(self)
      unless account_description.empty?
        result << {
          name: authenticator.name,
          description: account_description,
        }
      end
    end

    result
  end

  USER_FIELD_PREFIX ||= "user_field_"

  def user_fields
    return @user_fields if @user_fields
    user_field_ids = UserField.pluck(:id)
    if user_field_ids.present?
      @user_fields = {}
      user_field_ids.each do |fid|
        @user_fields[fid.to_s] = custom_fields["#{USER_FIELD_PREFIX}#{fid}"]
      end
    end
    @user_fields
  end

  def number_of_deleted_posts
    Post.with_deleted
      .where(user_id: self.id)
      .where.not(deleted_at: nil)
      .count
  end

  def number_of_flagged_posts
    Post.with_deleted
      .where(user_id: self.id)
      .where(id: PostAction.where(post_action_type_id: PostActionType.notify_flag_type_ids)
                             .where(disagreed_at: nil)
                             .select(:post_id))
      .count
  end

  def number_of_flags_given
    PostAction.where(user_id: self.id)
      .where(disagreed_at: nil)
      .where(post_action_type_id: PostActionType.notify_flag_type_ids)
      .count
  end

  def number_of_suspensions
    UserHistory.for(self, :suspend_user).count
  end

  def create_user_profile
    UserProfile.create!(user_id: id)
  end

  def set_random_avatar
    if SiteSetting.selectable_avatars_enabled? && SiteSetting.selectable_avatars.present?
      urls = SiteSetting.selectable_avatars.split("\n")
      if urls.present?
        if upload = Upload.find_by(url: urls.sample)
          update_column(:uploaded_avatar_id, upload.id)
          UserAvatar.create!(user_id: id, custom_upload_id: upload.id)
        end
      end
    end
  end

  def anonymous?
    SiteSetting.allow_anonymous_posting &&
      trust_level >= 1 &&
      !!anonymous_user_master
  end

  def is_singular_admin?
    User.where(admin: true).where.not(id: id).human_users.blank?
  end

  def logged_out
    MessageBus.publish "/logout", self.id, user_ids: [self.id]
    DiscourseEvent.trigger(:user_logged_out, self)
  end

  def logged_in
    DiscourseEvent.trigger(:user_logged_in, self)

    if !self.seen_before?
      DiscourseEvent.trigger(:user_first_logged_in, self)
    end
  end

  def set_automatic_groups
    return if !active || staged || !email_confirmed?

    Group.where(automatic: false)
      .where("LENGTH(COALESCE(automatic_membership_email_domains, '')) > 0")
      .each do |group|

      domains = group.automatic_membership_email_domains.gsub('.', '\.')

      if email =~ Regexp.new("@(#{domains})$", true) && !group.users.include?(self)
        group.add(self)
        GroupActionLogger.new(Discourse.system_user, group).log_add_user_to_group(self)
      end
    end
  end

  def email
    primary_email.email
  end

  def email=(new_email)
    if primary_email
      new_record? ? primary_email.email = new_email : primary_email.update(email: new_email)
    else
      self.primary_email = UserEmail.new(email: new_email, user: self, primary: true)
    end
  end

  def emails
    self.user_emails.order("user_emails.primary DESC NULLS LAST").pluck(:email)
  end

  def secondary_emails
    self.user_emails.secondary.pluck(:email)
  end

  def recent_time_read
    self.created_at && self.created_at < 60.days.ago ?
      self.user_visits.where('visited_at >= ?', 60.days.ago).sum(:time_read) :
      self.user_stat&.time_read
  end

  def from_staged?
    custom_fields[User::FROM_STAGED]
  end

  def mature_staged?
    from_staged? && self.created_at && self.created_at < 1.day.ago
  end

  def next_best_title
    group_titles_query = groups.where("groups.title <> ''")
    group_titles_query = group_titles_query.order("groups.id = #{primary_group_id} DESC") if primary_group_id
    group_titles_query = group_titles_query.order("groups.primary_group DESC").limit(1)

    if next_best_group_title = group_titles_query.pluck_first(:title)
      return next_best_group_title
    end

    next_best_badge_title = badges.where(allow_title: true).pluck_first(:name)
    next_best_badge_title ? Badge.display_name(next_best_badge_title) : nil
  end

  def create_reviewable
    return unless SiteSetting.must_approve_users? || SiteSetting.invite_only?
    return if approved?

    Jobs.enqueue(:create_user_reviewable, user_id: self.id)
  end

  def has_more_posts_than?(max_post_count)
    return true if user_stat && (user_stat.topic_count + user_stat.post_count) > max_post_count

    DB.query_single(<<~SQL, user_id: self.id).first > max_post_count
      SELECT COUNT(1)
      FROM (
        SELECT 1
        FROM posts p
               JOIN topics t ON (p.topic_id = t.id)
        WHERE p.user_id = :user_id AND
          p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          (
            t.archetype <> 'private_message' OR
              EXISTS(
                  SELECT 1
                  FROM topic_allowed_users a
                  WHERE a.topic_id = t.id AND a.user_id > 0 AND a.user_id <> :user_id
                ) OR
              EXISTS(
                  SELECT 1
                  FROM topic_allowed_groups g
                  WHERE g.topic_id = p.topic_id
                )
            )
        LIMIT #{max_post_count + 1}
      ) x
    SQL
  end

  def create_or_fetch_secure_identifier
    return secure_identifier if secure_identifier.present?
    new_secure_identifier = SecureRandom.hex(20)
    self.update(secure_identifier: new_secure_identifier)
    new_secure_identifier
  end

  def second_factor_security_key_credential_ids
    security_keys
      .select(:credential_id)
      .where(factor_type: UserSecurityKey.factor_types[:second_factor])
      .pluck(:credential_id)
  end

  protected

  def badge_grant
    BadgeGranter.queue_badge_grant(Badge::Trigger::UserChange, user: self)
  end

  def expire_old_email_tokens
    if saved_change_to_password_hash? && !saved_change_to_id?
      email_tokens.where('not expired').update_all(expired: true)
    end
  end

  def index_search
    SearchIndexer.index(self)
  end

  def clear_global_notice_if_needed
    return if id < 0

    if admin && SiteSetting.has_login_hint
      SiteSetting.has_login_hint = false
      SiteSetting.global_notice = ""
    end
  end

  def ensure_in_trust_level_group
    Group.user_trust_level_change!(id, trust_level)
  end

  def create_user_stat
    stat = UserStat.new(new_since: Time.now)
    stat.user_id = id
    stat.save!
  end

  def create_user_option
    UserOption.create!(user_id: id)
  end

  def create_email_token
    email_tokens.create!(email: email)
  end

  def ensure_password_is_hashed
    if @raw_password
      self.salt = SecureRandom.hex(16)
      self.password_hash = hash_password(@raw_password, salt)
    end
  end

  def expire_tokens_if_password_changed
    # NOTE: setting raw password is the only valid way of changing a password
    # the password field in the DB is actually hashed, nobody should be amending direct
    if @raw_password
      # Association in model may be out-of-sync
      UserAuthToken.where(user_id: id).destroy_all
      # We should not carry this around after save
      @raw_password = nil
      @password_required = false
    end
  end

  def hash_password(password, salt)
    raise StandardError.new("password is too long") if password.size > User.max_password_length
    Pbkdf2.hash_password(password, salt, Rails.configuration.pbkdf2_iterations, Rails.configuration.pbkdf2_algorithm)
  end

  def add_trust_level
    # there is a possibility we did not load trust level column, skip it
    return unless has_attribute? :trust_level
    self.trust_level ||= SiteSetting.default_trust_level
  end

  def update_usernames
    self.username.unicode_normalize!
    self.username_lower = username.downcase
  end

  USERNAME_EXISTS_SQL = <<~SQL
    (SELECT users.id AS id, true as is_user FROM users
    WHERE users.username_lower = :username)

    UNION ALL

    (SELECT groups.id, false as is_user FROM groups
    WHERE lower(groups.name) = :username)
  SQL

  def self.username_exists?(username)
    username = normalize_username(username)
    DB.exec(User::USERNAME_EXISTS_SQL, username: username) > 0
  end

  def username_validator
    username_format_validator || begin
      if will_save_change_to_username?
        existing = DB.query(
          USERNAME_EXISTS_SQL,
          username: self.class.normalize_username(username)
        )

        user_id = existing.select { |u| u.is_user }.first&.id
        same_user = user_id && user_id == self.id

        if existing.present? && !same_user
          errors.add(:username, I18n.t(:'user.username.unique'))
        end

        if confirm_password?(username) || confirm_password?(username.downcase)
          errors.add(:username, :same_as_password)
        end
      end
    end
  end

  def name_validator
    if name.present? &&
      (confirm_password?(name) || confirm_password?(name&.downcase))

      errors.add(:name, :same_as_password)
    end
  end

  def set_default_categories_preferences
    return if self.staged?

    values = []

    %w{watching watching_first_post tracking muted}.each do |s|
      category_ids = SiteSetting.get("default_categories_#{s}").split("|").map(&:to_i)
      category_ids.each do |category_id|
        next if category_id == 0
        values << "(#{self.id}, #{category_id}, #{CategoryUser.notification_levels[s.to_sym]})"
      end
    end

    if values.present?
      DB.exec("INSERT INTO category_users (user_id, category_id, notification_level) VALUES #{values.join(",")}")
    end
  end

  def self.purge_unactivated
    return [] if SiteSetting.purge_unactivated_users_grace_period_days <= 0

    destroyer = UserDestroyer.new(Discourse.system_user)

    User
      .where(active: false)
      .where("created_at < ?", SiteSetting.purge_unactivated_users_grace_period_days.days.ago)
      .where("NOT admin AND NOT moderator")
      .where("NOT EXISTS
              (SELECT 1 FROM topic_allowed_users tu JOIN topics t ON t.id = tu.topic_id AND t.user_id > 0 WHERE tu.user_id = users.id LIMIT 1)
            ")
      .limit(200)
      .find_each do |user|
      begin
        destroyer.destroy(user, context: I18n.t(:purge_reason))
      rescue Discourse::InvalidAccess, UserDestroyer::PostsExistError
        # keep going
      end
    end
  end

  def match_title_to_primary_group_changes
    return unless primary_group_id_changed?

    if title == Group.where(id: primary_group_id_was).pluck_first(:title)
      self.title = primary_group&.title
    end
  end

  private

  def trigger_user_automatic_group_refresh
    if !staged
      Group.user_trust_level_change!(id, trust_level)
    end
    true
  end

  def trigger_user_updated_event
    DiscourseEvent.trigger(:user_updated, self)
    true
  end

  def check_if_title_is_badged_granted
    if title_changed? && !new_record? && user_profile
      badge_granted_title = title.present? && badges.where(allow_title: true, name: title).exists?
      user_profile.update_column(:badge_granted_title, badge_granted_title)
    end
  end

  def previous_visit_at_update_required?(timestamp)
    seen_before? && (last_seen_at < (timestamp - SiteSetting.previous_visit_timeout_hours.hours))
  end

  def update_previous_visit(timestamp)
    update_visit_record!(timestamp.to_date)
    if previous_visit_at_update_required?(timestamp)
      update_column(:previous_visit_at, last_seen_at)
    end
  end

  def trigger_user_created_event
    DiscourseEvent.trigger(:user_created, self)
    true
  end

  def trigger_user_destroyed_event
    DiscourseEvent.trigger(:user_destroyed, self)
    true
  end

  def set_skip_validate_email
    if self.primary_email
      self.primary_email.skip_validate_email = !should_validate_email_address?
    end

    true
  end

  def check_site_contact_username
    if (saved_change_to_admin? || saved_change_to_moderator?) &&
        self.username == SiteSetting.site_contact_username && !staff?
      SiteSetting.set_and_log(:site_contact_username, SiteSetting.defaults[:site_contact_username])
    end
  end

  def self.ensure_consistency!
    DB.exec <<~SQL
      UPDATE users
      SET uploaded_avatar_id = NULL
      WHERE uploaded_avatar_id IN (
        SELECT u1.uploaded_avatar_id FROM users u1
        LEFT JOIN uploads up
          ON u1.uploaded_avatar_id = up.id
        WHERE u1.uploaded_avatar_id IS NOT NULL AND
          up.id IS NULL
      )
    SQL
  end

end

# == Schema Information
#
# Table name: users
#
#  id                        :integer          not null, primary key
#  username                  :string(60)       not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  name                      :string
#  seen_notification_id      :integer          default(0), not null
#  last_posted_at            :datetime
#  password_hash             :string(64)
#  salt                      :string(32)
#  active                    :boolean          default(FALSE), not null
#  username_lower            :string(60)       not null
#  last_seen_at              :datetime
#  admin                     :boolean          default(FALSE), not null
#  last_emailed_at           :datetime
#  trust_level               :integer          not null
#  approved                  :boolean          default(FALSE), not null
#  approved_by_id            :integer
#  approved_at               :datetime
#  previous_visit_at         :datetime
#  suspended_at              :datetime
#  suspended_till            :datetime
#  date_of_birth             :date
#  views                     :integer          default(0), not null
#  flag_level                :integer          default(0), not null
#  ip_address                :inet
#  moderator                 :boolean          default(FALSE)
#  title                     :string
#  uploaded_avatar_id        :integer
#  locale                    :string(10)
#  primary_group_id          :integer
#  registration_ip_address   :inet
#  staged                    :boolean          default(FALSE), not null
#  first_seen_at             :datetime
#  silenced_till             :datetime
#  group_locked_trust_level  :integer
#  manual_locked_trust_level :integer
#  secure_identifier         :string
#
# Indexes
#
#  idx_users_admin                    (id) WHERE admin
#  idx_users_moderator                (id) WHERE moderator
#  index_users_on_last_posted_at      (last_posted_at)
#  index_users_on_last_seen_at        (last_seen_at)
#  index_users_on_secure_identifier   (secure_identifier) UNIQUE
#  index_users_on_uploaded_avatar_id  (uploaded_avatar_id)
#  index_users_on_username            (username) UNIQUE
#  index_users_on_username_lower      (username_lower) UNIQUE
#
