class Badge < ActiveRecord::Base

  # badge ids
  Welcome = 5
  NicePost = 6
  GoodPost = 7
  GreatPost = 8
  Autobiographer = 9
  Editor = 10
  PayingItForward = 11

  # other consts
  AutobiographerMinBioLength = 10


  module Queries
    PayingItForward = <<SQL
    SELECT pa.user_id, min(post_id) post_id, min(pa.created_at) granted_at
    FROM post_actions pa
    JOIN posts p on p.id = pa.post_id
    JOIN topics t on t.id = p.topic_id
    WHERE p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          t.visible AND
          post_action_type_id = 2
    GROUP BY pa.user_id
SQL

    Editor = <<SQL
    SELECT p.user_id, min(p.id) post_id, min(p.created_at) granted_at
    FROM posts p
    JOIN topics t on t.id = p.topic_id
    WHERE p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          t.visible AND
          p.self_edits > 0
    GROUP BY p.user_id
SQL

    Welcome = <<SQL
    SELECT p.user_id, min(post_id) post_id, min(pa.created_at) granted_at
    FROM post_actions pa
    JOIN posts p on p.id = pa.post_id
    JOIN topics t on t.id = p.topic_id
    WHERE p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          t.visible AND
          post_action_type_id = 2
    GROUP BY p.user_id
SQL

    Autobiographer = <<SQL
    SELECT u.id user_id, current_timestamp granted_at
    FROM users u
    JOIN user_profiles up on u.id = up.user_id
    WHERE bio_raw IS NOT NULL AND LENGTH(TRIM(bio_raw)) > #{Badge::AutobiographerMinBioLength} AND
          uploaded_avatar_id IS NOT NULL
SQL

    def self.like_badge(count)
      # we can do better with dates, but its hard work
"
    SELECT p.user_id, p.id post_id, p.updated_at granted_at FROM posts p
    JOIN topics t on p.topic_id = t.id
    WHERE p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          t.visible AND
          p.like_count >= #{count.to_i}
"
    end

    def self.trust_level(level)
      # we can do better with dates, but its hard work figuring this out historically
"
    SELECT u.id user_id, current_timestamp granted_at FROM users u
    WHERE trust_level >= #{level.to_i}
"
    end
  end

  belongs_to :badge_type
  has_many :user_badges, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :badge_type, presence: true
  validates :allow_title, inclusion: [true, false]
  validates :multiple_grant, inclusion: [true, false]


  def self.trust_level_badge_ids
    (1..4).to_a
  end

  def self.like_badge_counts
    @like_badge_counts ||= {
      NicePost => 10,
      GoodPost => 25,
      GreatPost => 50
    }
  end

  def reset_grant_count!
    self.grant_count = UserBadge.where(badge_id: id).count
    save!
  end

  def single_grant?
    !self.multiple_grant?
  end

end

# == Schema Information
#
# Table name: badges
#
#  id             :integer          not null, primary key
#  name           :string(255)      not null
#  description    :text
#  badge_type_id  :integer          not null
#  grant_count    :integer          default(0), not null
#  created_at     :datetime
#  updated_at     :datetime
#  allow_title    :boolean          default(FALSE), not null
#  multiple_grant :boolean          default(FALSE), not null
#  icon           :string(255)      default("fa-certificate")
#  listable       :boolean          default(TRUE)
#  target_posts   :boolean          default(FALSE)
#  query          :text
#
# Indexes
#
#  index_badges_on_name  (name) UNIQUE
#
