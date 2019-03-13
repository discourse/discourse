# frozen_string_literal: true

require_dependency 'enum'

class Group < ActiveRecord::Base
  include HasCustomFields
  include AnonCacheInvalidator
  include HasDestroyedWebHook

  cattr_accessor :preloaded_custom_field_names
  self.preloaded_custom_field_names = Set.new

  has_many :category_groups, dependent: :destroy
  has_many :group_users, dependent: :destroy
  has_many :group_requests, dependent: :destroy
  has_many :group_mentions, dependent: :destroy

  has_many :group_archived_messages, dependent: :destroy

  has_many :categories, through: :category_groups
  has_many :users, through: :group_users
  has_many :requesters, through: :group_requests, source: :user
  has_many :group_histories, dependent: :destroy
  has_many :category_reviews, class_name: 'Category', foreign_key: :reviewable_by_group_id, dependent: :nullify
  has_many :reviewables, foreign_key: :reviewable_by_group_id, dependent: :nullify

  has_many :mailboxes, -> { order 'lower(name)' }, dependent: :destroy

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

  def expire_cache
    ApplicationSerializer.expire_cache_fragment!("group_names")
    SvgSprite.expire_cache
  end

  def remove_review_groups
    puts self.id!
    Category.where(review_group_id: self.id).update_all(review_group_id: nil)
    Category.where(review_group_id: self.id).update_all(review_group_id: nil)
  end

  validate :name_format_validator
  validates :name, presence: true
  validate :automatic_membership_email_domains_format_validator
  validate :incoming_email_validator
  validate :can_allow_membership_requests, if: :allow_membership_requests
  validates :flair_url, url: true, if: Proc.new { |g| g.flair_url && g.flair_url.exclude?('fa-') }
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

  ALIAS_LEVELS = {
    nobody: 0,
    only_admins: 1,
    mods_and_admins: 2,
    members_mods_and_admins: 3,
    everyone: 99
  }

  def self.visibility_levels
    @visibility_levels = Enum.new(
      public: 0,
      members: 1,
      staff: 2,
      owners: 3
    )
  end

  validates :mentionable_level, inclusion: { in: ALIAS_LEVELS.values }
  validates :messageable_level, inclusion: { in: ALIAS_LEVELS.values }

  scope :visible_groups, Proc.new { |user, order, opts|
    groups = self.order(order || "name ASC")

    if !opts || !opts[:include_everyone]
      groups = groups.where("groups.id > 0")
    end

    unless user&.admin
      sql = <<~SQL
        groups.id IN (
          SELECT g.id FROM groups g WHERE g.visibility_level = :public

          UNION ALL

          SELECT g.id FROM groups g
          JOIN group_users gu ON gu.group_id = g.id AND
                                 gu.user_id = :user_id
          WHERE g.visibility_level = :members

          UNION ALL

          SELECT g.id FROM groups g
          LEFT JOIN group_users gu ON gu.group_id = g.id AND
                                 gu.user_id = :user_id AND
                                 gu.owner
          WHERE g.visibility_level = :staff AND (gu.id IS NOT NULL OR :is_staff)

          UNION ALL

          SELECT g.id FROM groups g
          JOIN group_users gu ON gu.group_id = g.id AND
                                 gu.user_id = :user_id AND
                                 gu.owner
          WHERE g.visibility_level = :owners

        )
      SQL

      groups = groups.where(
        sql,
        Group.visibility_levels.to_h.merge(user_id: user&.id, is_staff: !!user&.staff?)
      )

    end

    groups
  }

  scope :mentionable, lambda { |user|
    where(self.mentionable_sql_clause,
      levels: alias_levels(user),
      user_id: user&.id
    )
  }

  scope :messageable, lambda { |user|
    where("messageable_level in (:levels) OR
          (
            messageable_level = #{ALIAS_LEVELS[:members_mods_and_admins]} AND id in (
            SELECT group_id FROM group_users WHERE user_id = :user_id)
          )", levels: alias_levels(user), user_id: user && user.id)
  }

  def self.mentionable_sql_clause
    <<~SQL
    mentionable_level in (:levels)
    OR (
      mentionable_level = #{ALIAS_LEVELS[:members_mods_and_admins]}
      AND id in (
        SELECT group_id FROM group_users WHERE user_id = :user_id)
      )
    SQL
  end

  def self.alias_levels(user)
    levels = [ALIAS_LEVELS[:everyone]]

    if user && user.admin?
      levels = [ALIAS_LEVELS[:everyone],
                ALIAS_LEVELS[:only_admins],
                ALIAS_LEVELS[:mods_and_admins],
                ALIAS_LEVELS[:members_mods_and_admins]]
    elsif user && user.moderator?
      levels = [ALIAS_LEVELS[:everyone],
                ALIAS_LEVELS[:mods_and_admins],
                ALIAS_LEVELS[:members_mods_and_admins]]
    end

    levels
  end

  def downcase_incoming_email
    self.incoming_email = (incoming_email || "").strip.downcase.presence
  end

  def cook_bio
    if !self.bio_raw.blank?
      self.bio_cooked = PrettyText.cook(self.bio_raw)
    end
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
      .where(post_type: Post.types[:regular])

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
    localized_name = User.normalize_username(I18n.t("groups.default_names.#{name}", locale: SiteSetting.default_locale))
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

    # Remove people from groups they don't belong in.
    remove_subquery =
      case name
      when :admins
        "SELECT id FROM users WHERE id <= 0 OR NOT admin"
      when :moderators
        "SELECT id FROM users WHERE id <= 0 OR NOT moderator"
      when :staff
        "SELECT id FROM users WHERE id <= 0 OR (NOT admin AND NOT moderator)"
      when :trust_level_0, :trust_level_1, :trust_level_2, :trust_level_3, :trust_level_4
        "SELECT id FROM users WHERE id <= 0 OR trust_level < #{id - 10}"
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
        "SELECT id FROM users WHERE id > 0 AND admin"
      when :moderators
        "SELECT id FROM users WHERE id > 0 AND moderator"
      when :staff
        "SELECT id FROM users WHERE id > 0 AND (moderator OR admin)"
      when :trust_level_1, :trust_level_2, :trust_level_3, :trust_level_4
        "SELECT id FROM users WHERE id > 0 AND trust_level >= #{id - 10}"
      when :trust_level_0
        "SELECT id FROM users WHERE id > 0"
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

  def self.search_groups(name, groups: nil)
    (groups || Group).where(
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
      group_ids = group_ids.split(",")
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
          group.group_users.create!(user_id: user_id)
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

  def add(user)
    self.users.push(user) unless self.users.include?(user)

    if self.categories.count < PUBLISH_CATEGORIES_LIMIT
      MessageBus.publish('/categories', {
        categories: ActiveModel::ArraySerializer.new(self.categories).as_json
      }, user_ids: [user.id])
    else
      Discourse.request_refresh!(user_ids: [user.id])
    end

    self
  end

  def remove(user)
    self.group_users.where(user: user).each(&:destroy)
    user.update_columns(primary_group_id: nil) if user.primary_group_id == self.id
  end

  def add_owner(user)
    if group_user = self.group_users.find_by(user: user)
      group_user.update!(owner: true) if !group_user.owner
    else
      self.group_users.create!(user: user, owner: true)
    end
  end

  def self.find_by_email(email)
    self.where("string_to_array(incoming_email, '|') @> ARRAY[?]", Email.downcase(email)).first
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

  def staff?
    STAFF_GROUPS.include?(self.name.to_sym)
  end

  def self.member_of(groups, user)
    groups.joins(
      "LEFT JOIN group_users gu ON gu.group_id = groups.id
    ").where("gu.user_id = ?", user.id)
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

    domains = self.automatic_membership_email_domains.split("|")
    domains.each do |domain|
      domain.sub!(/^https?:\/\//, '')
      domain.sub!(/\/.*$/, '')
      self.errors.add :base, (I18n.t('groups.errors.invalid_domain', domain: domain)) unless domain =~ /\A[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,24}(:[0-9]{1,5})?(\/.*)?\Z/i
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
    if self.automatic_membership_retroactive
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

      builder = DB.build(sql)
      builder.where(<<~SQL, id: id)
        id IN (
          SELECT user_id
          FROM group_users
          WHERE group_id = :id
        )
      SQL

      if primary_group
        builder.set("primary_group_id = :id")
      else
        builder.set("primary_group_id = NULL")
        builder.where("primary_group_id = :id")
      end

      builder.exec
    end
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
#  automatic_membership_retroactive   :boolean          default(FALSE)
#  primary_group                      :boolean          default(FALSE), not null
#  title                              :string
#  grant_trust_level                  :integer
#  incoming_email                     :string
#  has_messages                       :boolean          default(FALSE), not null
#  flair_url                          :string
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
#  email_smtp_server                  :string
#  email_smtp_port                    :integer
#  email_smtp_ssl                     :boolean
#  email_imap_server                  :string
#  email_imap_port                    :integer
#  email_imap_ssl                     :boolean
#  email_username                     :string
#  email_password                     :string
#
# Indexes
#
#  index_groups_on_incoming_email  (incoming_email) UNIQUE
#  index_groups_on_name            (name) UNIQUE
#
