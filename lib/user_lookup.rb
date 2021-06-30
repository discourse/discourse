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
    @primary_groups ||= begin
      hash = {}
      users.values.each do |u|
        if u.primary_group_id
          hash[u.id] = groups[u.primary_group_id]
        end
      end
      hash
    end
  end

  def flair_groups
    @flair_groups ||= begin
      hash = {}
      users.values.each do |u|
        if u.flair_group_id
          hash[u.id] = groups[u.flair_group_id]
        end
      end
      hash
    end
  end

  private

  def self.lookup_columns
    @user_lookup_columns ||= %i{id username name uploaded_avatar_id primary_group_id flair_group_id admin moderator trust_level}
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

  def groups
    @group_lookup = begin
      group_ids = users.values.map { |u| [u.primary_group_id, u.flair_group_id] }
      group_ids.flatten!
      group_ids.uniq!
      group_ids.compact!

      hash = {}

      Group.includes(:flair_upload)
        .where(id: group_ids)
        .select(self.class.group_lookup_columns)
        .each { |g| hash[g.id] = g }

      hash
    end
  end
end
