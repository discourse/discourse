class Group < ActiveRecord::Base
  include HasCustomFields

  has_many :category_groups, dependent: :destroy
  has_many :group_users, dependent: :destroy
  has_many :group_mentions, dependent: :destroy

  has_many :group_archived_messages, dependent: :destroy

  has_many :categories, through: :category_groups
  has_many :users, through: :group_users

  before_save :downcase_incoming_email

  after_save :destroy_deletions
  after_save :automatic_group_membership
  after_save :update_primary_group
  after_save :update_title

  after_save :expire_cache
  after_destroy :expire_cache

  def expire_cache
    ApplicationSerializer.expire_cache_fragment!("group_names")
  end

  validate :name_format_validator
  validates_uniqueness_of :name, case_sensitive: false
  validate :automatic_membership_email_domains_format_validator
  validate :incoming_email_validator

  AUTO_GROUPS = {
    :everyone => 0,
    :admins => 1,
    :moderators => 2,
    :staff => 3,
    :trust_level_0 => 10,
    :trust_level_1 => 11,
    :trust_level_2 => 12,
    :trust_level_3 => 13,
    :trust_level_4 => 14
  }

  AUTO_GROUP_IDS = Hash[*AUTO_GROUPS.to_a.flatten.reverse]
  STAFF_GROUPS = [:admins, :moderators, :staff]

  ALIAS_LEVELS = {
    :nobody => 0,
    :only_admins => 1,
    :mods_and_admins => 2,
    :members_mods_and_admins => 3,
    :everyone => 99
  }

  validates :alias_level, inclusion: { in: ALIAS_LEVELS.values}

  scope :mentionable, lambda {|user|

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

    where("alias_level in (:levels) OR
          (
            alias_level = #{ALIAS_LEVELS[:members_mods_and_admins]} AND id in (
            SELECT group_id FROM group_users WHERE user_id = :user_id)
          )", levels: levels, user_id: user && user.id )
  }

  def downcase_incoming_email
    self.incoming_email = (incoming_email || "").strip.downcase.presence
  end

  def incoming_email_validator
    return if self.automatic || self.incoming_email.blank?
    incoming_email.split("|").each do |email|
      if !Email.is_valid?(email)
        self.errors.add(:base, I18n.t('groups.errors.invalid_incoming_email', email: email))
      elsif group = Group.where.not(id: self.id).find_by_email(email)
        self.errors.add(:base, I18n.t('groups.errors.email_already_used_in_group', email: email, group_name: group.name))
      elsif category = Category.find_by_email(email)
        self.errors.add(:base, I18n.t('groups.errors.email_already_used_in_category', email: email, category_name: category.name))
      end
    end
  end

  def posts_for(guardian, before_post_id=nil)
    user_ids = group_users.map { |gu| gu.user_id }
    result = Post.includes(:user, :topic, topic: :category)
                 .references(:posts, :topics, :category)
                 .where(user_id: user_ids)
                 .where('topics.archetype <> ?', Archetype.private_message)
                 .where(post_type: Post.types[:regular])

    result = guardian.filter_allowed_categories(result)
    result = result.where('posts.id < ?', before_post_id) if before_post_id
    result.order('posts.created_at desc')
  end

  def messages_for(guardian, before_post_id=nil)
    result = Post.includes(:user, :topic, topic: :category)
                 .references(:posts, :topics, :category)
                 .where('topics.archetype = ?', Archetype.private_message)
                 .where(post_type: Post.types[:regular])
                 .where('topics.id IN (SELECT topic_id FROM topic_allowed_groups WHERE group_id = ?)', self.id)

    result = guardian.filter_allowed_categories(result)
    result = result.where('posts.id < ?', before_post_id) if before_post_id
    result.order('posts.created_at desc')
  end

  def mentioned_posts_for(guardian, before_post_id=nil)
    result = Post.joins(:group_mentions)
                 .includes(:user, :topic, topic: :category)
                 .references(:posts, :topics, :category)
                 .where('topics.archetype <> ?', Archetype.private_message)
                 .where(post_type: Post.types[:regular])
                 .where('group_mentions.group_id = ?', self.id)

    result = guardian.filter_allowed_categories(result)
    result = result.where('posts.id < ?', before_post_id) if before_post_id
    result.order('posts.created_at desc')
  end

  def self.trust_group_ids
    (10..19).to_a
  end

  def self.refresh_automatic_group!(name)
    return unless id = AUTO_GROUPS[name]

    unless group = self.lookup_group(name)
      group = Group.new(name: name.to_s, automatic: true)
      group.id = id
      group.save!
    end

    group.name = I18n.t("groups.default_names.#{name}")

    # don't allow shoddy localization to break this
    validator = UsernameValidator.new(group.name)
    unless validator.valid_format?
      group.name = name
    end

    # the everyone group is special, it can include non-users so there is no
    # way to have the membership in a table
    if name == :everyone
      group.save!
      return group
    end

    # Remove people from groups they don't belong in.
    #
    # BEWARE: any of these subqueries could match ALL the user records,
    #         so they can't be used in IN clauses.
    remove_user_subquery = case name
                when :admins
                  "SELECT u.id FROM users u WHERE NOT u.admin"
                when :moderators
                  "SELECT u.id FROM users u WHERE NOT u.moderator"
                when :staff
                  "SELECT u.id FROM users u WHERE NOT u.admin AND NOT u.moderator"
                when :trust_level_0, :trust_level_1, :trust_level_2, :trust_level_3, :trust_level_4
                  "SELECT u.id FROM users u WHERE u.trust_level < #{id - 10}"
                end

    remove_ids = exec_sql("SELECT gu.id id
                             FROM group_users gu,
                                  (#{remove_user_subquery}) u
                            WHERE gu.group_id = #{group.id}
                              AND gu.user_id = u.id").map {|x| x['id']}

    if remove_ids.length > 0
      remove_ids.each_slice(100) do |ids|
        GroupUser.where(id: ids).delete_all
      end
    end

    # Add people to groups
    real_ids = case name
               when :admins
                 "SELECT u.id FROM users u WHERE u.admin"
               when :moderators
                 "SELECT u.id FROM users u WHERE u.moderator"
               when :staff
                 "SELECT u.id FROM users u WHERE u.moderator OR u.admin"
               when :trust_level_1, :trust_level_2, :trust_level_3, :trust_level_4
                 "SELECT u.id FROM users u WHERE u.trust_level >= #{id-10}"
               when :trust_level_0
                 "SELECT u.id FROM users u"
               end

    missing_users = GroupUser
      .joins("RIGHT JOIN (#{real_ids}) X ON X.id = user_id AND group_id = #{group.id}")
      .where("user_id IS NULL")
      .select("X.id")

    missing_users.each do |u|
      group.group_users.build(user_id: u.id)
    end

    group.save!

    # we want to ensure consistency
    Group.reset_counters(group.id, :group_users)

    group
  end

  def self.ensure_consistency!
    reset_all_counters!
    refresh_automatic_groups!
  end

  def self.reset_all_counters!
    Group.pluck(:id).each do |group_id|
      Group.reset_counters(group_id, :group_users)
    end
  end

  def self.refresh_automatic_groups!(*args)
    if args.length == 0
      args = AUTO_GROUPS.keys
    end
    args.each do |group|
      refresh_automatic_group!(group)
    end
  end

  def self.ensure_automatic_groups!
    AUTO_GROUPS.each_key do |name|
      refresh_automatic_group!(name) unless lookup_group(name)
    end
  end

  def self.[](name)
    lookup_group(name) || refresh_automatic_group!(name)
  end

  def self.search_group(name)
    Group.where(visible: true).where("name ILIKE :term_like", term_like: "#{name}%")
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

  def self.lookup_group_ids(opts)
    if group_ids = opts[:group_ids]
      group_ids = group_ids.split(",").map(&:to_i)
      group_ids = Group.where(id: group_ids).pluck(:id)
    end

    group_ids ||= []

    if group_names = opts[:group_names]
      group_names = group_names.split(",")
      if group_names.present?
        group_ids += Group.where(name: group_names).pluck(:id)
      end
    end

    group_ids
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

  def self.builtin
    Enum.new(:moderators, :admins, :trust_level_1, :trust_level_2)
  end

  def usernames=(val)
    current = usernames.split(",")
    expected = val.split(",")

    additions = expected - current
    deletions = current - expected

    map = Hash[*User.where(username: additions+deletions)
                 .select('id,username')
                 .map{|u| [u.username,u.id]}.flatten]

    deletions = Set.new(deletions.map{|d| map[d]})

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

  def add(user)
    self.users.push(user)
  end

  def remove(user)
    self.group_users.where(user: user).each(&:destroy)
    user.update_columns(primary_group_id: nil) if user.primary_group_id == self.id
  end

  def add_owner(user)
    self.group_users.create(user_id: user.id, owner: true)
  end

  def self.find_by_email(email)
    self.where("string_to_array(incoming_email, '|') @> ARRAY[?]", Email.downcase(email)).first
  end

  def bulk_add(user_ids)
    if user_ids.present?
      Group.exec_sql("INSERT INTO group_users
                                  (group_id, user_id, created_at, updated_at)
                     SELECT #{self.id},
                            u.id,
                            CURRENT_TIMESTAMP,
                            CURRENT_TIMESTAMP
                     FROM users AS u
                     WHERE u.id IN (#{user_ids.join(', ')})
                       AND NOT EXISTS(SELECT 1 FROM group_users AS gu
                                      WHERE gu.user_id = u.id AND
                                            gu.group_id = #{self.id})")

      if self.primary_group?
        User.where(id: user_ids).update_all(primary_group_id: self.id)
      end

      if self.title.present?
        User.where(id: user_ids).update_all(title: self.title)
      end
    end
    true
  end

  def mentionable?(user, group_id)
    Group.mentionable(user).where(id: group_id).exists?
  end

  def staff?
    STAFF_GROUPS.include?(self.name.to_sym)
  end

  protected

    def name_format_validator
      UsernameValidator.perform_validation(self, 'name')
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

      if self.title_changed?
        sql = <<SQL
        UPDATE users SET title = :title
        WHERE (title = :title_was OR
              title = '' OR
              title IS NULL) AND
              COALESCE(title,'') <> COALESCE(:title,'') AND
              id IN (
                SELECT user_id
                FROM group_users
                WHERE group_id = :id
              )
SQL

        self.class.exec_sql(sql,
              title: title,
              title_was: title_was,
              id: id
        )
      end
    end

    def update_primary_group
      return if new_record? && !self.primary_group?

      if self.primary_group_changed?
        sql = <<SQL
        UPDATE users
        /*set*/
        /*where*/
SQL

        builder = SqlBuilder.new(sql)
        builder.where("
              id IN (
                SELECT user_id
                FROM group_users
                WHERE group_id = :id
              )", id: id)

        if primary_group
          builder.set("primary_group_id = :id")
        else
          builder.set("primary_group_id = NULL")
          builder.where("primary_group_id = :id")
        end

        builder.exec
      end
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
#  alias_level                        :integer          default(0)
#  visible                            :boolean          default(TRUE), not null
#  automatic_membership_email_domains :text
#  automatic_membership_retroactive   :boolean          default(FALSE)
#  primary_group                      :boolean          default(FALSE), not null
#  title                              :string
#  grant_trust_level                  :integer
#  incoming_email                     :string
#  has_messages                       :boolean          default(FALSE), not null
#
# Indexes
#
#  index_groups_on_incoming_email  (incoming_email) UNIQUE
#  index_groups_on_name            (name) UNIQUE
#
