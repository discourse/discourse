# frozen_string_literal: true

require 'net/imap'

class Group < ActiveRecord::Base
  # TODO(2021-05-26): remove
  self.ignored_columns = %w{
    automatic_membership_retroactive
    flair_url
  }

  include HasCustomFields
  include AnonCacheInvalidator
  include HasDestroyedWebHook
  include GlobalPath

  cattr_accessor :preloaded_custom_field_names
  self.preloaded_custom_field_names = Set.new

  has_many :category_groups, dependent: :destroy
  has_many :group_users, dependent: :destroy
  has_many :group_requests, dependent: :destroy
  has_many :group_mentions, dependent: :destroy
  has_many :group_associated_groups, dependent: :destroy

  has_many :group_archived_messages, dependent: :destroy

  has_many :categories, through: :category_groups
  has_many :users, through: :group_users
  has_many :requesters, through: :group_requests, source: :user
  has_many :group_histories, dependent: :destroy
  has_many :category_reviews, class_name: 'Category', foreign_key: :reviewable_by_group_id, dependent: :nullify
  has_many :reviewables, foreign_key: :reviewable_by_group_id, dependent: :nullify
  has_many :group_category_notification_defaults, dependent: :destroy
  has_many :group_tag_notification_defaults, dependent: :destroy
  has_many :associated_groups, through: :group_associated_groups, dependent: :destroy

  belongs_to :flair_upload, class_name: 'Upload'
  belongs_to :smtp_updated_by, class_name: 'User'
  belongs_to :imap_updated_by, class_name: 'User'

  has_and_belongs_to_many :web_hooks

  before_save :downcase_incoming_email
  before_save :cook_bio

  after_save :destroy_deletions
  after_save :update_primary_group
  after_save :update_title

  after_save :enqueue_update_mentions_job,
    if: Proc.new { |g| g.name_before_last_save && g.saved_change_to_name? }

  after_save :expire_cache
  after_destroy :expire_cache

  after_commit :automatic_group_membership, on: [:create, :update]
  after_commit :trigger_group_created_event, on: :create
  after_commit :trigger_group_updated_event, on: :update
  after_commit :trigger_group_destroyed_event, on: :destroy
  after_commit :set_default_notifications, on: [:create, :update]

  def expire_cache
    ApplicationSerializer.expire_cache_fragment!("group_names")
    SvgSprite.expire_cache
    expire_imap_mailbox_cache
  end

  def expire_imap_mailbox_cache
    Discourse.cache.delete("group_imap_mailboxes_#{self.id}")
  end

  def remove_review_groups
    Category.where(review_group_id: self.id).update_all(review_group_id: nil)
  end

  validate :name_format_validator
  validates :name, presence: true
  validate :automatic_membership_email_domains_format_validator
  validate :incoming_email_validator
  validate :can_allow_membership_requests, if: :allow_membership_requests
  validate :validate_grant_trust_level, if: :will_save_change_to_grant_trust_level?

  AUTO_GROUPS = {
    everyone: 0,
    admins: 1,
    moderators: 2,
    staff: 3,
    trust_level_0: 10,
    trust_level_1: 11,
    trust_level_2: 12,
    trust_level_3: 13,
    trust_level_4: 14
  }

  AUTO_GROUP_IDS = Hash[*AUTO_GROUPS.to_a.flatten.reverse]
  STAFF_GROUPS = [:admins, :moderators, :staff]

  IMAP_SETTING_ATTRIBUTES = [
    "imap_server",
    "imap_port",
    "imap_ssl",
    "imap_mailbox_name",
    "email_username",
    "email_password"
  ]

  SMTP_SETTING_ATTRIBUTES = [
    "imap_server",
    "imap_port",
    "imap_ssl",
    "email_username",
    "email_password",
    "email_from_alias"
  ]

  ALIAS_LEVELS = {
    nobody: 0,
    only_admins: 1,
    mods_and_admins: 2,
    members_mods_and_admins: 3,
    owners_mods_and_admins: 4,
    everyone: 99
  }

  VALID_DOMAIN_REGEX = /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,24}(:[0-9]{1,5})?(\/.*)?\Z/i

  def self.visibility_levels
    @visibility_levels = Enum.new(
      public: 0,
      logged_on_users: 1,
      members: 2,
      staff: 3,
      owners: 4
    )
  end

  validates :mentionable_level, inclusion: { in: ALIAS_LEVELS.values }
  validates :messageable_level, inclusion: { in: ALIAS_LEVELS.values }

  scope :with_imap_configured, -> { where(imap_enabled: true).where.not(imap_mailbox_name: '') }
  scope :with_smtp_configured, -> { where(smtp_enabled: true) }

  scope :visible_groups, Proc.new { |user, order, opts|
    groups = self.order(order || "name ASC")

    if !opts || !opts[:include_everyone]
      groups = groups.where("groups.id > 0")
    end

    if !user&.admin
      is_staff = !!user&.staff?

      if user.blank?
        sql = "groups.visibility_level = :public"
      elsif is_staff
        sql = "groups.visibility_level IN (:public, :logged_on_users, :members, :staff)"
      else
        sql = <<~SQL
          groups.id IN (
            SELECT id
              FROM groups
            WHERE visibility_level IN (:public, :logged_on_users)

            UNION ALL

            SELECT g.id
              FROM groups g
              JOIN group_users gu ON gu.group_id = g.id AND gu.user_id = :user_id
            WHERE g.visibility_level = :members

            UNION ALL

            SELECT g.id
              FROM groups g
              JOIN group_users gu ON gu.group_id = g.id AND gu.user_id = :user_id AND gu.owner
            WHERE g.visibility_level IN (:staff, :owners)
          )
        SQL
      end

      params = Group.visibility_levels.to_h.merge(user_id: user&.id, is_staff: is_staff)
      groups = groups.where(sql, params)
    end

    groups
  }

  scope :members_visible_groups, Proc.new { |user, order, opts|
    groups = self.order(order || "name ASC")

    if !opts || !opts[:include_everyone]
      groups = groups.where("groups.id > 0")
    end

    if !user&.admin
      is_staff = !!user&.staff?

      if user.blank?
        sql = "groups.members_visibility_level = :public"
      elsif is_staff
        sql = "groups.members_visibility_level IN (:public, :logged_on_users, :members, :staff)"
      else
        sql = <<~SQL
          groups.id IN (
            SELECT id
              FROM groups
            WHERE members_visibility_level IN (:public, :logged_on_users)

            UNION ALL

            SELECT g.id
              FROM groups g
              JOIN group_users gu ON gu.group_id = g.id AND gu.user_id = :user_id
            WHERE g.members_visibility_level = :members

            UNION ALL

            SELECT g.id
              FROM groups g
              JOIN group_users gu ON gu.group_id = g.id AND gu.user_id = :user_id AND gu.owner
            WHERE g.members_visibility_level IN (:staff, :owners)
          )
        SQL
      end

      params = Group.visibility_levels.to_h.merge(user_id: user&.id, is_staff: is_staff)
      groups = groups.where(sql, params)
    end

    groups
  }

  scope :mentionable, lambda { |user, include_public: true|
    where(self.mentionable_sql_clause(include_public: include_public),
      levels: alias_levels(user),
      user_id: user&.id
    )
  }

  scope :messageable, lambda { |user|
    where("messageable_level in (:levels) OR
          (
            messageable_level = #{ALIAS_LEVELS[:members_mods_and_admins]} AND id in (
            SELECT group_id FROM group_users WHERE user_id = :user_id)
          ) OR (
            messageable_level = #{ALIAS_LEVELS[:owners_mods_and_admins]} AND id in (
            SELECT group_id FROM group_users WHERE user_id = :user_id AND owner IS TRUE)
          )", levels: alias_levels(user), user_id: user && user.id)
  }

  def self.mentionable_sql_clause(include_public: true)
    clause = +<<~SQL
      mentionable_level in (:levels)
      OR (
        mentionable_level = #{ALIAS_LEVELS[:members_mods_and_admins]}
        AND id in (
          SELECT group_id FROM group_users WHERE user_id = :user_id)
      ) OR (
        mentionable_level = #{ALIAS_LEVELS[:owners_mods_and_admins]}
        AND id in (
          SELECT group_id FROM group_users WHERE user_id = :user_id AND owner IS TRUE)
      )
      SQL

    if include_public
      clause << "OR visibility_level = #{Group.visibility_levels[:public]}"
    end

    clause
  end

  def self.alias_levels(user)
    if user&.admin?
      [
        ALIAS_LEVELS[:everyone],
        ALIAS_LEVELS[:only_admins],
        ALIAS_LEVELS[:mods_and_admins],
        ALIAS_LEVELS[:members_mods_and_admins],
        ALIAS_LEVELS[:owners_mods_and_admins],
      ]
    elsif user&.moderator?
      [
        ALIAS_LEVELS[:everyone],
        ALIAS_LEVELS[:mods_and_admins],
        ALIAS_LEVELS[:members_mods_and_admins],
        ALIAS_LEVELS[:owners_mods_and_admins],
      ]
    else
      [ALIAS_LEVELS[:everyone]]
    end
  end

  def smtp_from_address
    self.email_from_alias.present? ? self.email_from_alias : self.email_username
  end

  def downcase_incoming_email
    self.incoming_email = (incoming_email || "").strip.downcase.presence
  end

  def cook_bio
    if self.bio_raw.present?
      self.bio_cooked = PrettyText.cook(self.bio_raw)
    else
      self.bio_cooked = nil
    end
  end

  def record_email_setting_changes!(user)
    if (self.previous_changes.keys & IMAP_SETTING_ATTRIBUTES).any?
      self.imap_updated_at = Time.zone.now
      self.imap_updated_by_id = user.id
    end

    if (self.previous_changes.keys & SMTP_SETTING_ATTRIBUTES).any?
      self.smtp_updated_at = Time.zone.now
      self.smtp_updated_by_id = user.id
    end

    self.smtp_enabled = [self.smtp_port, self.smtp_server, self.email_password, self.email_username].all?(&:present?)
    self.imap_enabled = [self.imap_port, self.imap_server, self.email_password, self.email_username].all?(&:present?)

    self.save
  end

  def incoming_email_validator
    return if self.automatic || self.incoming_email.blank?

    incoming_email.split("|").each do |email|
      escaped = Rack::Utils.escape_html(email)
      if !Email.is_valid?(email)
        self.errors.add(:base, I18n.t('groups.errors.invalid_incoming_email', email: escaped))
      elsif group = Group.where.not(id: self.id).find_by_email(email)
        self.errors.add(:base, I18n.t('groups.errors.email_already_used_in_group', email: escaped, group_name: Rack::Utils.escape_html(group.name)))
      elsif category = Category.find_by_email(email)
        self.errors.add(:base, I18n.t('groups.errors.email_already_used_in_category', email: escaped, category_name: Rack::Utils.escape_html(category.name)))
      end
    end
  end

  def posts_for(guardian, opts = nil)
    opts ||= {}
    result = Post.joins(:topic, user: :groups, topic: :category)
      .preload(:topic, user: :groups, topic: :category)
      .references(:posts, :topics, :category)
      .where(groups: { id: id })
      .where('topics.archetype <> ?', Archetype.private_message)
      .where('topics.visible')
      .where(post_type: [Post.types[:regular], Post.types[:moderator_action]])

    if opts[:category_id].present?
      result = result.where('topics.category_id = ?', opts[:category_id].to_i)
    end

    result = guardian.filter_allowed_categories(result)
    result = result.where('posts.id < ?', opts[:before_post_id].to_i) if opts[:before_post_id]
    result.order('posts.created_at desc')
  end

  def messages_for(guardian, opts = nil)
    opts ||= {}

    result = Post.includes(:user, :topic, topic: :category)
      .references(:posts, :topics, :category)
      .where('topics.archetype = ?', Archetype.private_message)
      .where(post_type: Post.types[:regular])
      .where('topics.id IN (SELECT topic_id FROM topic_allowed_groups WHERE group_id = ?)', self.id)

    if opts[:category_id].present?
      result = result.where('topics.category_id = ?', opts[:category_id].to_i)
    end

    result = guardian.filter_allowed_categories(result)
    result = result.where('posts.id < ?', opts[:before_post_id].to_i) if opts[:before_post_id]
    result.order('posts.created_at desc')
  end

  def mentioned_posts_for(guardian, opts = nil)
    opts ||= {}
    result = Post.joins(:group_mentions)
      .includes(:user, :topic, topic: :category)
      .references(:posts, :topics, :category)
      .where('topics.archetype <> ?', Archetype.private_message)
      .where(post_type: Post.types[:regular])
      .where('group_mentions.group_id = ?', self.id)

    if opts[:category_id].present?
      result = result.where('topics.category_id = ?', opts[:category_id].to_i)
    end

    result = guardian.filter_allowed_categories(result)
    result = result.where('posts.id < ?', opts[:before_post_id].to_i) if opts[:before_post_id]
    result.order('posts.created_at desc')
  end

  def self.trust_group_ids
    (10..19).to_a
  end

  def set_message_default_notification_levels!(topic, ignore_existing: false)
    group_users.pluck(:user_id, :notification_level).each do |user_id, notification_level|
      next if user_id == -1
      next if user_id == topic.user_id
      next if ignore_existing && TopicUser.where(user_id: user_id, topic_id: topic.id).exists?

      action =
        case notification_level
        when TopicUser.notification_levels[:tracking] then "track!"
        when TopicUser.notification_levels[:regular]  then "regular!"
        when TopicUser.notification_levels[:muted]    then "mute!"
        when TopicUser.notification_levels[:watching] then "watch!"
        else "track!"
        end

      topic.notifier.public_send(action, user_id)
    end
  end

  def self.set_category_and_tag_default_notification_levels!(user, group_name)
    if group = lookup_group(group_name)
      GroupUser.set_category_notifications(group, user)
      GroupUser.set_tag_notifications(group, user)
    end
  end

  def self.refresh_automatic_group!(name)
    return unless id = AUTO_GROUPS[name]

    unless group = self.lookup_group(name)
      group = Group.new(name: name.to_s, automatic: true)

      if AUTO_GROUPS[:moderators] == id
        group.default_notification_level = 2
        group.messageable_level = ALIAS_LEVELS[:everyone]
      end

      group.id = id
      group.save!
    end

    # don't allow shoddy localization to break this
    localized_name = I18n.t("groups.default_names.#{name}", locale: SiteSetting.default_locale)
    validator = UsernameValidator.new(localized_name)

    if validator.valid_format? && !User.username_exists?(localized_name)
      group.name = localized_name
    end

    # the everyone group is special, it can include non-users so there is no
    # way to have the membership in a table
    case name
    when :everyone
      group.visibility_level = Group.visibility_levels[:staff]
      group.save!
      return group
    when :moderators
      group.update!(messageable_level: ALIAS_LEVELS[:everyone])
    end

    group.update!(visibility_level: Group.visibility_levels[:logged_on_users]) if group.visibility_level == Group.visibility_levels[:public]

    # Remove people from groups they don't belong in.
    remove_subquery =
      case name
      when :admins
        "SELECT id FROM users WHERE id <= 0 OR NOT admin OR staged"
      when :moderators
        "SELECT id FROM users WHERE id <= 0 OR NOT moderator OR staged"
      when :staff
        "SELECT id FROM users WHERE id <= 0 OR (NOT admin AND NOT moderator) OR staged"
      when :trust_level_0, :trust_level_1, :trust_level_2, :trust_level_3, :trust_level_4
        "SELECT id FROM users WHERE id <= 0 OR trust_level < #{id - 10} OR staged"
      end

    DB.exec <<-SQL
      DELETE FROM group_users
            USING (#{remove_subquery}) X
            WHERE group_id = #{group.id}
              AND user_id = X.id
    SQL

    # Add people to groups
    insert_subquery =
      case name
      when :admins
        "SELECT id FROM users WHERE id > 0 AND admin AND NOT staged"
      when :moderators
        "SELECT id FROM users WHERE id > 0 AND moderator AND NOT staged"
      when :staff
        "SELECT id FROM users WHERE id > 0 AND (moderator OR admin) AND NOT staged"
      when :trust_level_1, :trust_level_2, :trust_level_3, :trust_level_4
        "SELECT id FROM users WHERE id > 0 AND trust_level >= #{id - 10} AND NOT staged"
      when :trust_level_0
        "SELECT id FROM users WHERE id > 0 AND NOT staged"
      end

    DB.exec <<-SQL
      INSERT INTO group_users (group_id, user_id, created_at, updated_at)
           SELECT #{group.id}, X.id, now(), now()
             FROM group_users
       RIGHT JOIN (#{insert_subquery}) X ON X.id = user_id AND group_id = #{group.id}
            WHERE user_id IS NULL
    SQL

    group.save!

    # we want to ensure consistency
    Group.reset_counters(group.id, :group_users)

    group
  end

  def self.ensure_consistency!
    reset_all_counters!
    refresh_automatic_groups!
    refresh_has_messages!
  end

  def self.reset_all_counters!
    DB.exec <<-SQL
      WITH X AS (
          SELECT group_id
               , COUNT(user_id) users
            FROM group_users
        GROUP BY group_id
      )
      UPDATE groups
         SET user_count = X.users
        FROM X
       WHERE id = X.group_id
         AND user_count <> X.users
    SQL
  end

  def self.refresh_automatic_groups!(*args)
    args = AUTO_GROUPS.keys if args.empty?
    args.each { |group| refresh_automatic_group!(group) }
  end

  def self.refresh_has_messages!
    DB.exec <<-SQL
      UPDATE groups g SET has_messages = false
      WHERE NOT EXISTS (SELECT tg.id
                          FROM topic_allowed_groups tg
                    INNER JOIN topics t ON t.id = tg.topic_id
                         WHERE tg.group_id = g.id
                           AND t.deleted_at IS NULL)
      AND g.has_messages = true
    SQL
  end

  def self.ensure_automatic_groups!
    AUTO_GROUPS.each_key do |name|
      refresh_automatic_group!(name) unless lookup_group(name)
    end
  end

  def self.[](name)
    lookup_group(name) || refresh_automatic_group!(name)
  end

  def self.search_groups(name, groups: nil, custom_scope: {})
    groups ||= Group

    groups.where(
      "name ILIKE :term_like OR full_name ILIKE :term_like", term_like: "%#{name}%"
    )
  end

  def self.lookup_group(name)
    if id = AUTO_GROUPS[name]
      Group.find_by(id: id)
    else
      unless group = Group.find_by(name: name)
        raise ArgumentError, "unknown group"
      end
      group
    end
  end

  def self.lookup_groups(group_ids: [], group_names: [])
    if group_ids.present?
      group_ids = group_ids.split(",") if group_ids.is_a?(String)
      group_ids.map!(&:to_i)
      groups = Group.where(id: group_ids) if group_ids.present?
    end

    if group_names.present?
      group_names = group_names.split(",")
      groups = (groups || Group).where(name: group_names) if group_names.present?
    end

    groups || []
  end

  def self.desired_trust_level_groups(trust_level)
    trust_group_ids.keep_if do |id|
      id == AUTO_GROUPS[:trust_level_0] || (trust_level + 10) >= id
    end
  end

  def self.user_trust_level_change!(user_id, trust_level)
    desired = desired_trust_level_groups(trust_level)
    undesired = trust_group_ids - desired

    GroupUser.where(group_id: undesired, user_id: user_id).delete_all

    desired.each do |id|
      if group = find_by(id: id)
        unless GroupUser.where(group_id: id, user_id: user_id).exists?
          group_user = group.group_users.create!(user_id: user_id)
          DiscourseEvent.trigger(:user_added_to_group, group_user.user, group, automatic: true)
        end
      else
        name = AUTO_GROUP_IDS[trust_level]
        refresh_automatic_group!(name)
      end
    end
  end

  # given something that might be a group name, id, or record, return the group id
  def self.group_id_from_param(group_param)
    return group_param.id if group_param.is_a?(Group)
    return group_param if group_param.is_a?(Integer)

    # subtle, using Group[] ensures the group exists in the DB
    Group[group_param.to_sym].id
  end

  def self.builtin
    Enum.new(:moderators, :admins, :trust_level_1, :trust_level_2)
  end

  def usernames=(val)
    current = usernames.split(",")
    expected = val.split(",")

    additions = expected - current
    deletions = current - expected

    map = Hash[*User.where(username: additions + deletions)
      .select('id,username')
      .map { |u| [u.username, u.id] }.flatten]

    deletions = Set.new(deletions.map { |d| map[d] })

    @deletions = []
    group_users.each do |gu|
      @deletions << gu if deletions.include?(gu.user_id)
    end

    additions.each do |a|
      group_users.build(user_id: map[a])
    end

  end

  def usernames
    users.pluck(:username).join(",")
  end

  PUBLISH_CATEGORIES_LIMIT = 10

  def add(user, notify: false, automatic: false)
    return self if self.users.include?(user)

    self.users.push(user)

    if notify
      Notification.create!(
        notification_type: Notification.types[:membership_request_accepted],
        user_id: user.id,
        data: { group_id: id, group_name: name }.to_json
      )
    end

    if self.categories.count < PUBLISH_CATEGORIES_LIMIT
      MessageBus.publish('/categories', {
        categories: ActiveModel::ArraySerializer.new(self.categories).as_json
      }, user_ids: [user.id])
    else
      Discourse.request_refresh!(user_ids: [user.id])
    end

    DiscourseEvent.trigger(:user_added_to_group, user, self, automatic: automatic)

    self
  end

  def remove(user)
    group_user = self.group_users.find_by(user: user)
    return false if group_user.blank?

    has_webhooks = WebHook.active_web_hooks(:group_user)
    payload = WebHook.generate_payload(:group_user, group_user, WebHookGroupUserSerializer) if has_webhooks
    group_user.destroy
    DiscourseEvent.trigger(:user_removed_from_group, user, self)
    WebHook.enqueue_hooks(:group_user, :user_removed_from_group,
      id: group_user.id,
      payload: payload
    ) if has_webhooks
    true
  end

  def add_owner(user)
    if group_user = self.group_users.find_by(user: user)
      group_user.update!(owner: true) if !group_user.owner
    else
      self.group_users.create!(user: user, owner: true)
    end
  end

  def self.find_by_email(email)
    self.where(
      "email_username = :email OR
        string_to_array(incoming_email, '|') @> ARRAY[:email] OR
        email_from_alias = :email",
      email: Email.downcase(email)
    ).first
  end

  def bulk_add(user_ids)
    return unless user_ids.present?

    Group.transaction do
      sql = <<~SQL
      INSERT INTO group_users
        (group_id, user_id, created_at, updated_at)
      SELECT
        #{self.id},
        u.id,
        CURRENT_TIMESTAMP,
        CURRENT_TIMESTAMP
      FROM users AS u
      WHERE u.id IN (:user_ids)
      AND NOT EXISTS (
        SELECT 1 FROM group_users AS gu
        WHERE gu.user_id = u.id AND
        gu.group_id = :group_id
      )
      SQL

      DB.exec(sql, group_id: self.id, user_ids: user_ids)

      user_attributes = {}

      if self.primary_group?
        user_attributes[:primary_group_id] = self.id
      end

      if self.title.present?
        user_attributes[:title] = self.title
      end

      if user_attributes.present?
        User.where(id: user_ids).update_all(user_attributes)
      end

      # update group user count
      DB.exec <<~SQL
        UPDATE groups g
        SET user_count =
          (SELECT COUNT(gu.user_id)
           FROM group_users gu
           WHERE gu.group_id = g.id)
        WHERE g.id = #{self.id};
      SQL
    end

    if self.grant_trust_level.present?
      Jobs.enqueue(:bulk_grant_trust_level,
        user_ids: user_ids,
        trust_level: self.grant_trust_level
      )
    end

    self
  end

  def add_automatically(user, subject: nil)
    if users.exclude?(user) && add(user)
      logger = GroupActionLogger.new(Discourse.system_user, self)
      logger.log_add_user_to_group(user, subject)
    end
  end

  def remove_automatically(user, subject: nil)
    if users.include?(user) && remove(user)
      logger = GroupActionLogger.new(Discourse.system_user, self)
      logger.log_remove_user_from_group(user, subject)
    end
  end

  def staff?
    STAFF_GROUPS.include?(self.name.to_sym)
  end

  def self.member_of(groups, user)
    groups
      .joins("LEFT JOIN group_users gu ON gu.group_id = groups.id ")
      .where("gu.user_id = ?", user.id)
  end

  def self.owner_of(groups, user)
    self.member_of(groups, user).where("gu.owner")
  end

  %i{
    group_created
    group_updated
    group_destroyed
  }.each do |event|
    define_method("trigger_#{event}_event") do
      DiscourseEvent.trigger(event, self)
      true
    end
  end

  def flair_type
    return :icon if flair_icon.present?
    return :image if flair_upload.present?
  end

  def flair_url
    return flair_icon if flair_type == :icon
    return upload_cdn_path(flair_upload.url) if flair_type == :image

    nil
  end

  [:muted, :regular, :tracking, :watching, :watching_first_post].each do |level|
    define_method("#{level}_category_ids=") do |category_ids|
      @category_notifications ||= {}
      @category_notifications[level] = category_ids
    end

    define_method("#{level}_tags=") do |tag_names|
      @tag_notifications ||= {}
      @tag_notifications[level] = tag_names
    end
  end

  def set_default_notifications
    if @category_notifications
      @category_notifications.each do |level, category_ids|
        GroupCategoryNotificationDefault.batch_set(self, level, category_ids)
      end
    end

    if @tag_notifications
      @tag_notifications.each do |level, tag_names|
        GroupTagNotificationDefault.batch_set(self, level, tag_names)
      end
    end
  end

  def imap_mailboxes
    return [] if !self.imap_enabled || !SiteSetting.enable_imap

    Discourse.cache.fetch("group_imap_mailboxes_#{self.id}", expires_in: 30.minutes) do
      Rails.logger.info("[IMAP] Refreshing mailboxes list for group #{self.name}")
      mailboxes = []

      begin
        imap_provider = Imap::Providers::Detector.init_with_detected_provider(
          self.imap_config
        )
        imap_provider.connect!
        mailboxes = imap_provider.filter_mailboxes(imap_provider.list_mailboxes_with_attributes)
        imap_provider.disconnect!

        update_columns(imap_last_error: nil)
      rescue => ex
        Rails.logger.warn("[IMAP] Mailbox refresh failed for group #{self.name} with error: #{ex}")
        update_columns(imap_last_error: ex.message)
      end

      mailboxes
    end
  end

  def imap_config
    {
      server: self.imap_server,
      port: self.imap_port,
      ssl: self.imap_ssl,
      username: self.email_username,
      password: self.email_password
    }
  end

  def email_username_domain
    email_username.split('@').last
  end

  def email_username_user
    email_username.split('@').first
  end

  def email_username_regex
    user = email_username_user
    domain = email_username_domain
    if user.present? && domain.present?
      /^#{Regexp.escape(user)}(\+[^@]*)?@#{Regexp.escape(domain)}$/i
    end
  end

  def notify_added_to_group(user, owner: false)
    SystemMessage.create_from_system_user(
      user,
      owner ? :user_added_to_group_as_owner : :user_added_to_group_as_member,
      group_name: name_full_preferred,
      group_path: "/g/#{self.name}"
    )
  end

  def name_full_preferred
    self.full_name.presence || self.name
  end

  def message_count
    return 0 unless self.has_messages
    TopicAllowedGroup.where(group_id: self.id).joins(:topic).count
  end

  protected

  def name_format_validator
    return if !name_changed?

    # avoid strip! here, it works now
    # but may not continue to work long term, especially
    # once we start returning frozen strings
    if self.name != (stripped = self.name.unicode_normalize.strip)
      self.name = stripped
    end

    UsernameValidator.perform_validation(self, 'name') || begin
      normalized_name = User.normalize_username(self.name)

      if self.will_save_change_to_name? && User.normalize_username(self.name_was) != normalized_name && User.username_exists?(self.name)
        errors.add(:name, I18n.t("activerecord.errors.messages.taken"))
      end
    end
  end

  def automatic_membership_email_domains_format_validator
    return if self.automatic_membership_email_domains.blank?

    domains = Group.get_valid_email_domains(self.automatic_membership_email_domains) do |domain|
      self.errors.add :base, (I18n.t('groups.errors.invalid_domain', domain: domain))
    end

    self.automatic_membership_email_domains = domains.join("|")
  end

  # hack around AR
  def destroy_deletions
    if @deletions
      @deletions.each do |gu|
        gu.destroy
        User.where('id = ? AND primary_group_id = ?', gu.user_id, gu.group_id).update_all 'primary_group_id = NULL'
      end
    end
    @deletions = nil
  end

  def automatic_group_membership
    if self.automatic_membership_email_domains.present?
      Jobs.enqueue(:automatic_group_membership, group_id: self.id)
    end
  end

  def update_title
    return if new_record? && !self.title.present?

    if self.saved_change_to_title?
      sql = <<~SQL
        UPDATE users
           SET title = :title
         WHERE (title = :title_was OR title = '' OR title IS NULL)
           AND COALESCE(title,'') <> COALESCE(:title,'')
           AND id IN (SELECT user_id FROM group_users WHERE group_id = :id)
      SQL

      DB.exec(sql, title: title, title_was: title_before_last_save, id: id)
    end
  end

  def update_primary_group
    return if new_record? && !self.primary_group?

    if self.saved_change_to_primary_group?
      sql = <<~SQL
        UPDATE users
        /*set*/
        /*where*/
      SQL

      [:primary_group_id, :flair_group_id].each do |column|
        builder = DB.build(sql)
        builder.where(<<~SQL, id: id)
          id IN (
            SELECT user_id
            FROM group_users
            WHERE group_id = :id
          )
        SQL

        if primary_group
          builder.set("#{column} = :id")
          builder.where("#{column} IS NULL") if column == :flair_group_id
        else
          builder.set("#{column} = NULL")
          builder.where("#{column} = :id")
        end

        builder.exec
      end
    end
  end

  def self.automatic_membership_users(domains, group_id = nil)
    pattern = "@(#{domains.gsub('.', '\.')})$"

    users = User.joins(:user_emails).where("user_emails.email ~* ?", pattern).activated.where(staged: false)
    users = users.where("users.id NOT IN (SELECT user_id FROM group_users WHERE group_users.group_id = ?)", group_id) if group_id.present?

    users
  end

  def self.get_valid_email_domains(value)
    valid_domains = []

    value.split("|").each do |domain|
      domain.sub!(/^https?:\/\//, '')
      domain.sub!(/\/.*$/, '')

      if domain =~ Group::VALID_DOMAIN_REGEX
        valid_domains << domain
      else
        yield domain if block_given?
      end
    end

    valid_domains
  end

  private

  def validate_grant_trust_level
    unless TrustLevel.valid?(self.grant_trust_level)
      self.errors.add(:base, I18n.t(
        'groups.errors.grant_trust_level_not_valid',
        trust_level: self.grant_trust_level
      ))
    end
  end

  def can_allow_membership_requests
    valid = true

    valid =
      if self.persisted?
        self.group_users.where(owner: true).exists?
      else
        self.group_users.any?(&:owner)
      end

    if !valid
      self.errors.add(:base, I18n.t('groups.errors.cant_allow_membership_requests'))
    end
  end

  def enqueue_update_mentions_job
    Jobs.enqueue(:update_group_mentions,
      previous_name: self.name_before_last_save,
      group_id: self.id
    )
  end
end

# == Schema Information
#
# Table name: groups
#
#  id                                 :integer          not null, primary key
#  name                               :string           not null
#  created_at                         :datetime         not null
#  updated_at                         :datetime         not null
#  automatic                          :boolean          default(FALSE), not null
#  user_count                         :integer          default(0), not null
#  automatic_membership_email_domains :text
#  primary_group                      :boolean          default(FALSE), not null
#  title                              :string
#  grant_trust_level                  :integer
#  incoming_email                     :string
#  has_messages                       :boolean          default(FALSE), not null
#  flair_bg_color                     :string
#  flair_color                        :string
#  bio_raw                            :text
#  bio_cooked                         :text
#  allow_membership_requests          :boolean          default(FALSE), not null
#  full_name                          :string
#  default_notification_level         :integer          default(3), not null
#  visibility_level                   :integer          default(0), not null
#  public_exit                        :boolean          default(FALSE), not null
#  public_admission                   :boolean          default(FALSE), not null
#  membership_request_template        :text
#  messageable_level                  :integer          default(0)
#  mentionable_level                  :integer          default(0)
#  smtp_server                        :string
#  smtp_port                          :integer
#  smtp_ssl                           :boolean
#  imap_server                        :string
#  imap_port                          :integer
#  imap_ssl                           :boolean
#  imap_mailbox_name                  :string           default(""), not null
#  imap_uid_validity                  :integer          default(0), not null
#  imap_last_uid                      :integer          default(0), not null
#  email_username                     :string
#  email_password                     :string
#  publish_read_state                 :boolean          default(FALSE), not null
#  members_visibility_level           :integer          default(0), not null
#  imap_last_error                    :text
#  imap_old_emails                    :integer
#  imap_new_emails                    :integer
#  flair_icon                         :string
#  flair_upload_id                    :integer
#  allow_unknown_sender_topic_replies :boolean          default(FALSE), not null
#  smtp_enabled                       :boolean          default(FALSE)
#  smtp_updated_at                    :datetime
#  smtp_updated_by_id                 :integer
#  imap_enabled                       :boolean          default(FALSE)
#  imap_updated_at                    :datetime
#  imap_updated_by_id                 :integer
#  email_from_alias                   :string
#
# Indexes
#
#  index_groups_on_incoming_email  (incoming_email) UNIQUE
#  index_groups_on_name            (name) UNIQUE
#
