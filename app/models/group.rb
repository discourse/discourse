class Group < ActiveRecord::Base
  include HasCustomFields

  has_many :category_groups
  has_many :group_users, dependent: :destroy

  has_many :categories, through: :category_groups
  has_many :users, through: :group_users

  after_save :destroy_deletions

  validate :name_format_validator
  validates_uniqueness_of :name

  AUTO_GROUPS = {
    :everyone => 0,
    :admins => 1,
    :moderators => 2,
    :staff => 3,
    :trust_level_0 => 10,
    :trust_level_1 => 11,
    :trust_level_2 => 12,
    :trust_level_3 => 13,
    :trust_level_4 => 14,
    :trust_level_5 => 15
  }

  AUTO_GROUP_IDS = Hash[*AUTO_GROUPS.to_a.reverse]

  ALIAS_LEVELS = {
    :nobody => 0,
    :only_admins => 1,
    :mods_and_admins => 2,
    :members_mods_and_admins => 3,
    :everyone => 99
  }

  validate :alias_level, inclusion: { in: ALIAS_LEVELS.values}

  def posts_for(guardian, before_post_id=nil)
    user_ids = group_users.map {|gu| gu.user_id}
    result = Post.where(user_id: user_ids).includes(:user, :topic).references(:posts, :topics)
                 .where('topics.archetype <> ?', Archetype.private_message)
                 .where(post_type: Post.types[:regular])

    unless guardian.is_staff?
      allowed_ids = guardian.allowed_category_ids
      if allowed_ids.length > 0
        result = result.where('topics.category_id IS NULL or topics.category_id IN (?)', allowed_ids)
      else
        result = result.where('topics.category_id IS NULL')
      end
    end

    result = result.where('posts.id < ?', before_post_id) if before_post_id
    result.order('posts.created_at desc')
  end

  def self.trust_group_ids
    (10..19).to_a
  end

  def self.refresh_automatic_group!(name)

    id = AUTO_GROUPS[name]
    return unless id

    unless group = self.lookup_group(name)
      group = Group.new(name: name.to_s, automatic: true)
      group.id = id
      group.save!
    end

    # the everyone group is special, it can include non-users so there is no
    # way to have the membership in a table
    return group if name == :everyone

    group.name = I18n.t("groups.default_names.#{name}")

    # don't allow shoddy localization to break this
    validator = UsernameValidator.new(group.name)
    unless validator.valid_format?
      group.name = name
    end

    real_ids = case name
               when :admins
                 "SELECT u.id FROM users u WHERE u.admin"
               when :moderators
                 "SELECT u.id FROM users u WHERE u.moderator"
               when :staff
                 "SELECT u.id FROM users u WHERE u.moderator OR u.admin"
               when :trust_level_1, :trust_level_2, :trust_level_3, :trust_level_4, :trust_level_5
                 "SELECT u.id FROM users u WHERE u.trust_level >= #{id-10}"
               when :trust_level_0
                 "SELECT u.id FROM users u"
               end


    extra_users = group.users.where("users.id NOT IN (#{real_ids})").select('users.id')
    missing_users = GroupUser
      .joins("RIGHT JOIN (#{real_ids}) X ON X.id = user_id AND group_id = #{group.id}")
      .where("user_id IS NULL")
      .select("X.id")

    group.group_users.where("user_id IN (#{extra_users.to_sql})").delete_all

    missing_users.each do |u|
      group.group_users.build(user_id: u.id)
    end

    group.save!

    # we want to ensure consistency
    Group.reset_counters(group.id, :group_users)

    group
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
    AUTO_GROUPS.keys.each do |name|
      refresh_automatic_group!(name) unless lookup_group(name)
    end
  end

  def self.[](name)
    lookup_group(name) || refresh_automatic_group!(name)
  end

  def self.search_group(name, current_user)
    levels = [ALIAS_LEVELS[:everyone]]

    if current_user.admin?
      levels = [ALIAS_LEVELS[:everyone],
                ALIAS_LEVELS[:only_admins],
                ALIAS_LEVELS[:mods_and_admins],
                ALIAS_LEVELS[:members_mods_and_admins]]
    elsif current_user.moderator?
      levels = [ALIAS_LEVELS[:everyone],
                ALIAS_LEVELS[:mods_and_admins],
                ALIAS_LEVELS[:members_mods_and_admins]]
    end

    Group.where("name ILIKE :term_like AND (" +
        " alias_level in (:levels)" +
        " OR (alias_level = #{ALIAS_LEVELS[:members_mods_and_admins]} AND id in (" +
            "SELECT group_id FROM group_users WHERE user_id= :user_id)" +
          ")" +
        ")", term_like: "#{name.downcase}%", levels: levels, user_id: current_user.id)
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
  protected

  def name_format_validator
    UsernameValidator.perform_validation(self, 'name')
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

end

# == Schema Information
#
# Table name: groups
#
#  id          :integer          not null, primary key
#  name        :string(255)      not null
#  created_at  :datetime
#  updated_at  :datetime
#  automatic   :boolean          default(FALSE), not null
#  user_count  :integer          default(0), not null
#  alias_level :integer          default(0)
#  visible     :boolean          default(TRUE), not null
#
# Indexes
#
#  index_groups_on_name  (name) UNIQUE
#
