class Group < ActiveRecord::Base
  has_many :category_groups
  has_many :group_users, dependent: :destroy

  has_many :categories, through: :category_groups
  has_many :users, through: :group_users

  after_save :destroy_deletions

  validate :name_format_validator

  AUTO_GROUPS = {
    :everyone => 0,
    :admins => 1,
    :moderators => 2,
    :staff => 3,
    :trust_level_1 => 11,
    :trust_level_2 => 12,
    :trust_level_3 => 13,
    :trust_level_4 => 14,
    :trust_level_5 => 15
  }

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
                 "SELECT u.id FROM users u WHERE u.trust_level = #{id-10}"
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

  def self.[](name)
    lookup_group(name) || refresh_automatic_group!(name)
  end

  def self.lookup_group(name)
    id = AUTO_GROUPS[name]
    if id
      Group.where(id: id).first
    else
      unless group = Group.where(name: name).first
        raise ArgumentError, "unknown group" unless group
      end
      group
    end
  end


  def self.user_trust_level_change!(user_id, trust_level)
    name = "trust_level_#{trust_level}".to_sym

    GroupUser.where(group_id: trust_group_ids, user_id: user_id).delete_all

    if group = lookup_group(name)
      group.group_users.build(user_id: user_id)
      group.save!
    else
      refresh_automatic_group!(name)
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
    group_users.delete_if do |gu|
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
      end
    end
    @deletions = nil
  end

end

# == Schema Information
#
# Table name: groups
#
#  id         :integer          not null, primary key
#  name       :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  automatic  :boolean          default(FALSE), not null
#  user_count :integer          default(0), not null
#
# Indexes
#
#  index_groups_on_name  (name) UNIQUE
#

