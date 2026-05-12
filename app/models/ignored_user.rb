# frozen_string_literal: true

class IgnoredUser < ActiveRecord::Base
  validates :expiring_at, presence: true

  belongs_to :user
  belongs_to :ignored_user, class_name: "User"

  # Excludes self and staff to match topic post filtering.
  def self.ignored_ids_for(user)
    return [] unless user

    DB.query_single(<<~SQL, current_user_id: user.id)
      SELECT ignored_user_id
      FROM ignored_users as ig
      INNER JOIN users as u ON u.id = ig.ignored_user_id
      WHERE ig.user_id = :current_user_id
        AND ig.ignored_user_id <> :current_user_id
        AND NOT u.admin
        AND NOT u.moderator
    SQL
  end
end

# == Schema Information
#
# Table name: ignored_users
#
#  id              :bigint           not null, primary key
#  user_id         :integer          not null
#  ignored_user_id :integer          not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  summarized_at   :datetime
#  expiring_at     :datetime         not null
#
# Indexes
#
#  index_ignored_users_on_ignored_user_id_and_user_id  (ignored_user_id,user_id) UNIQUE
#  index_ignored_users_on_user_id_and_ignored_user_id  (user_id,ignored_user_id) UNIQUE
#
