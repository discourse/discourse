class GroupUser < ActiveRecord::Base
  belongs_to :group, counter_cache: "user_count"
  belongs_to :user

  after_save :update_title
  after_destroy :remove_title

  after_save :set_primary_group
  after_destroy :remove_primary_group

  after_save :grant_trust_level

  protected

  def set_primary_group
    if group.primary_group
        self.class.exec_sql("UPDATE users
                             SET primary_group_id = :id
                             WHERE id = :user_id",
                          id: group.id, user_id: user_id)
    end
  end

  def remove_primary_group
      self.class.exec_sql("UPDATE users
                           SET primary_group_id = NULL
                           WHERE id = :user_id AND primary_group_id = :id",
                        id: group.id, user_id: user_id)

  end

  def remove_title
    if group.title.present?
        self.class.exec_sql("UPDATE users SET title = NULL
                          WHERE title = :title AND id = :id",
                          id: user_id,
                          title: group.title)
    end
  end

  def update_title
    if group.title.present?
      self.class.exec_sql("UPDATE users SET title = :title
                          WHERE (title IS NULL OR title = '') AND id = :id",
                          id: user_id,
                          title: group.title)
    end
  end

  def grant_trust_level
    return if group.grant_trust_level.nil?
    if user.trust_level < group.grant_trust_level
      user.change_trust_level!(group.grant_trust_level)
      user.trust_level_locked = true
      user.save
    end
  end
end

# == Schema Information
#
# Table name: group_users
#
#  id                 :integer          not null, primary key
#  group_id           :integer          not null
#  user_id            :integer          not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  owner              :boolean          default(FALSE), not null
#  notification_level :integer          default(2), not null
#
# Indexes
#
#  index_group_users_on_group_id_and_user_id  (group_id,user_id) UNIQUE
#  index_group_users_on_user_id_and_group_id  (user_id,group_id) UNIQUE
#
