# frozen_string_literal: true

class UserLookup
  def self.lookup_columns
    @user_lookup_columns ||= %i{id username name uploaded_avatar_id primary_group_id flair_group_id admin moderator trust_level}
  end

  def self.group_lookup_columns
    @group_lookup_columns ||= %i{id name flair_icon flair_upload_id flair_bg_color flair_color}
  end

  def initialize(user_ids = [])
    @user_ids = user_ids.tap(&:compact!).tap(&:uniq!).tap(&:flatten!)
  end

  # Lookup a user by id
  def [](user_id)
    users[user_id]
  end

  def primary_groups
    @primary_groups ||= users.values.each_with_object({}) do |user, hash|
      if user.primary_group_id
        hash[user.id] = groups[user.primary_group_id]
      end
    end
  end

  def flair_groups
    @flair_groups ||= users.values.each_with_object({}) do |user, hash|
      if user.flair_group_id
        hash[user.id] = groups[user.flair_group_id]
      end
    end
  end

  private

  def users
    @users ||= begin
      lookup_users = User.
        where(id: @user_ids).
        select(self.class.lookup_columns)

      if SiteSetting.enable_discourse_connect_external_id_serializers?
        lookup_users = lookup_users.includes(:single_sign_on_record)
      end

      lookup_users.index_by(&:id)
    end
  end

  def groups
    @group_lookup ||= begin
      group_ids = users.values.map { |u| [u.primary_group_id, u.flair_group_id] }
      group_ids.flatten!
      group_ids.uniq!
      group_ids.compact!

      Group
        .includes(:flair_upload)
        .where(id: group_ids)
        .select(self.class.group_lookup_columns)
        .index_by(&:id)
    end
  end
end
