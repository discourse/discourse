# frozen_string_literal: true

class UserLookup
  def self.lookup_columns
    @user_lookup_columns ||= %i[
      id
      username
      name
      uploaded_avatar_id
      primary_group_id
      flair_group_id
      admin
      moderator
      trust_level
    ]
  end

  def self.group_lookup_columns
    @group_lookup_columns ||= %i[id name flair_icon flair_upload_id flair_bg_color flair_color]
  end

  def initialize(user_ids = [])
    @user_ids = user_ids.tap(&:compact!).tap(&:uniq!).tap(&:flatten!)
  end

  # Lookup a user by id
  def [](user_id)
    users[user_id]
  end

  def primary_groups
    @primary_groups ||=
      users
        .values
        .each_with_object({}) do |user, hash|
          if user.primary_group_id
            group = groups[user.primary_group_id]
            set_user_group_preload(user, group, :primary_group)
            hash[user.id] = group
          end
        end
  end

  def flair_groups
    @flair_groups ||=
      users
        .values
        .each_with_object({}) do |user, hash|
          if user.flair_group_id
            group = groups[user.flair_group_id]
            set_user_group_preload(user, group, :flair_group)
            hash[user.id] = group
          end
        end
  end

  private

  def set_user_group_preload(user, group, group_association_name)
    association = user.association(group_association_name)
    association.target = group
  end

  def users
    @users ||= User.where(id: @user_ids).select(self.class.lookup_columns).index_by(&:id)
  end

  def groups
    @group_lookup ||=
      begin
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
