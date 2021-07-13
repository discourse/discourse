# frozen_string_literal: true

class UserLookup
  def self.lookup_columns
    @user_lookup_columns ||= %i{id username name uploaded_avatar_id primary_group_id flair_group_id admin moderator trust_level}
  end

  def self.group_lookup_columns
    @group_lookup_columns ||= %i{id name flair_icon flair_upload_id flair_bg_color flair_color}
  end

  def initialize(user_ids = [])
    @user_ids = user_ids.compact.uniq.flatten
  end

  # Lookup a user by id
  def [](user_id)
    users[user_id]
  end

  def primary_groups
    @primary_groups ||= users
      .values
      .filter(&:primary_group_id)
      .each_with_object({}) do |user, hash|
        hash[user.id] = groups[user.primary_group_id]
      end
  end

  def flair_groups
    @flair_groups ||= users
      .values
      .filter(&:flair_group_id)
      .each_with_object({}) do |user, hash|
        hash[user.id] = groups[user.flair_group_id]
      end
  end

  private

  def users
    @users ||= User
      .where(id: @user_ids)
      .select(self.class.lookup_columns)
      .index_by(&:id)
  end

  def groups
    @group_lookup ||= begin
      group_ids = users
        .values
        .map { |u| [u.primary_group_id, u.flair_group_id] }
        .flatten
        .uniq
        .compact

      Group
        .includes(:flair_upload)
        .where(id: group_ids)
        .select(self.class.group_lookup_columns)
        .index_by(&:id)
    end
  end
end
