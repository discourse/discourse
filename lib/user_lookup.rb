# frozen_string_literal: true

class UserLookup

  def initialize(user_ids = [])
    @user_ids = user_ids.tap(&:compact!).tap(&:uniq!).tap(&:flatten!)
  end

  # Lookup a user by id
  def [](user_id)
    users[user_id]
  end

  def primary_groups
    @groups ||= group_lookup_hash
  end

  private

  def self.lookup_columns
    @user_lookup_columns ||= %i{id username name uploaded_avatar_id primary_group_id admin moderator trust_level}
  end

  def self.group_lookup_columns
    @group_lookup_columns ||= %i{id name flair_icon flair_upload_id flair_bg_color flair_color}
  end

  def users
    @users ||= user_lookup_hash
  end

  def user_lookup_hash
    hash = {}
    User.where(id: @user_ids)
      .select(self.class.lookup_columns)
      .each { |user| hash[user.id] = user }
    hash
  end

  def group_lookup_hash
    users_with_primary_group = users.values.reject { |u| u.primary_group_id.nil? }

    group_lookup = {}
    group_ids = users_with_primary_group.map { |u| u.primary_group_id }
    group_ids.uniq!

    Group.includes(:flair_upload)
      .where(id: group_ids)
      .select(self.class.group_lookup_columns)
      .each { |g| group_lookup[g.id] = g }

    hash = {}
    users_with_primary_group.each do |u|
      hash[u.id] = group_lookup[u.primary_group_id]
    end
    hash
  end

end
