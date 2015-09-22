class Badge < ActiveRecord::Base
  # badge ids
  Welcome = 5
  NicePost = 6
  GoodPost = 7
  GreatPost = 8
  Autobiographer = 9
  Editor = 10
  FirstLike = 11
  FirstShare = 12
  FirstFlag = 13
  FirstLink = 14
  FirstQuote = 15
  ReadGuidelines = 16
  Reader = 17
  NiceTopic = 18
  GoodTopic = 19
  GreatTopic = 20
  NiceShare = 21
  GoodShare = 22
  GreatShare = 23
  OneYearAnniversary = 24
  Promoter = 25
  Campaigner = 26
  Champion = 27
  PopularLink = 28
  HotLink = 29
  FamousLink = 30

  # other consts
  AutobiographerMinBioLength = 10

  def self.trigger_hash
    Hash[*(
      Badge::Trigger.constants.map{|k|
        [k.to_s.underscore, Badge::Trigger.const_get(k)]
      }.flatten
    )]
  end

  module Trigger
    None = 0
    PostAction = 1
    PostRevision = 2
    TrustLevelChange = 4
    UserChange = 8

    def self.is_none?(trigger)
      [None].include? trigger
    end

    def self.uses_user_ids?(trigger)
      [TrustLevelChange, UserChange].include? trigger
    end

    def self.uses_post_ids?(trigger)
      [PostAction, PostRevision].include? trigger
    end
  end

  module Queries

    Reader = <<SQL
    SELECT id user_id, current_timestamp granted_at
    FROM users
    WHERE id IN
    (
      SELECT pt.user_id
      FROM post_timings pt
      JOIN badge_posts b ON b.post_number = pt.post_number AND
                            b.topic_id = pt.topic_id
      JOIN topics t ON t.id = pt.topic_id
      LEFT JOIN user_badges ub ON ub.badge_id = 17 AND ub.user_id = pt.user_id
      WHERE ub.id IS NULL AND t.posts_count > 100
      GROUP BY pt.user_id, pt.topic_id, t.posts_count
      HAVING count(*) >= t.posts_count
    )
SQL

    ReadGuidelines = <<SQL
    SELECT user_id, read_faq granted_at
    FROM user_stats
    WHERE read_faq IS NOT NULL AND (user_id IN (:user_ids) OR :backfill)
SQL

    FirstQuote = <<SQL
    SELECT ids.user_id, q.post_id, q.created_at granted_at
    FROM
    (
      SELECT p1.user_id, MIN(q1.id) id
      FROM quoted_posts q1
      JOIN badge_posts p1 ON p1.id = q1.post_id
      JOIN badge_posts p2 ON p2.id = q1.quoted_post_id
      WHERE (:backfill OR ( p1.id IN (:post_ids) ))
      GROUP BY p1.user_id
    ) ids
    JOIN quoted_posts q ON q.id = ids.id
SQL

    FirstLink = <<SQL
    SELECT l.user_id, l.post_id, l.created_at granted_at
    FROM
    (
      SELECT MIN(l1.id) id
      FROM topic_links l1
      JOIN badge_posts p1 ON p1.id = l1.post_id
      JOIN badge_posts p2 ON p2.id = l1.link_post_id
      WHERE NOT reflection AND p1.topic_id <> p2.topic_id AND not quote AND
        (:backfill OR ( p1.id in (:post_ids) ))
      GROUP BY l1.user_id
    ) ids
    JOIN topic_links l ON l.id = ids.id
SQL

    FirstShare = <<SQL
    SELECT views.user_id, i2.post_id, i2.created_at granted_at
    FROM
    (
      SELECT i.user_id, MIN(i.id) i_id
      FROM incoming_links i
      JOIN badge_posts p on p.id = i.post_id
      WHERE i.user_id IS NOT NULL
      GROUP BY i.user_id
    ) as views
    JOIN incoming_links i2 ON i2.id = views.i_id
SQL

    FirstFlag = <<SQL
    SELECT pa1.user_id, pa1.created_at granted_at, pa1.post_id
    FROM (
      SELECT pa.user_id, min(pa.id) id
      FROM post_actions pa
      JOIN badge_posts p on p.id = pa.post_id
      WHERE post_action_type_id IN (#{PostActionType.flag_types.values.join(",")}) AND
        (:backfill OR pa.post_id IN (:post_ids) )
      GROUP BY pa.user_id
    ) x
    JOIN post_actions pa1 on pa1.id = x.id
SQL

    FirstLike = <<SQL
    SELECT pa1.user_id, pa1.created_at granted_at, pa1.post_id
    FROM (
      SELECT pa.user_id, min(pa.id) id
      FROM post_actions pa
      JOIN badge_posts p on p.id = pa.post_id
      WHERE post_action_type_id = 2 AND
        (:backfill OR pa.post_id IN (:post_ids) )
      GROUP BY pa.user_id
    ) x
    JOIN post_actions pa1 on pa1.id = x.id
SQL

    # Incorrect, but good enough - (earlies post edited vs first edit)
    Editor = <<SQL
    SELECT p.user_id, min(p.id) post_id, min(p.created_at) granted_at
    FROM badge_posts p
    WHERE p.self_edits > 0 AND
        (:backfill OR p.id IN (:post_ids) )
    GROUP BY p.user_id
SQL

    Welcome = <<SQL
    SELECT p.user_id, min(post_id) post_id, min(pa.created_at) granted_at
    FROM post_actions pa
    JOIN badge_posts p on p.id = pa.post_id
    WHERE post_action_type_id = 2 AND
        (:backfill OR pa.post_id IN (:post_ids) )
    GROUP BY p.user_id
SQL

    Autobiographer = <<SQL
    SELECT u.id user_id, current_timestamp granted_at
    FROM users u
    JOIN user_profiles up on u.id = up.user_id
    WHERE bio_raw IS NOT NULL AND LENGTH(TRIM(bio_raw)) > #{Badge::AutobiographerMinBioLength} AND
          uploaded_avatar_id IS NOT NULL AND
          (:backfill OR u.id IN (:user_ids) )
SQL

    # member for a year + has posted at least once during that year
    OneYearAnniversary = <<-SQL
    SELECT u.id AS user_id, MIN(u.created_at + interval '1 year') AS granted_at
      FROM users u
      JOIN posts p ON p.user_id = u.id
     WHERE u.id > 0
       AND u.active
       AND NOT u.blocked
       AND u.created_at + interval '1 year' < now()
       AND p.deleted_at IS NULL
       AND NOT p.hidden
       AND p.created_at + interval '1 year' > now()
       AND (:backfill OR u.id IN (:user_ids))
     GROUP BY u.id
     HAVING COUNT(p.id) > 0
SQL

    def self.invite_badge(count,trust_level)
"
    SELECT u.id user_id, current_timestamp granted_at
    FROM users u
    WHERE u.id IN (
      SELECT invited_by_id
      FROM invites i
      JOIN users u2 ON u2.id = i.user_id
      WHERE i.deleted_at IS NULL AND u2.active AND u2.trust_level >= #{trust_level.to_i} AND not u2.blocked
      GROUP BY invited_by_id
      HAVING COUNT(*) > #{count.to_i}
    ) AND u.active AND NOT u.blocked AND u.id > 0 AND
      (:backfill OR u.id IN (:user_ids) )
"
    end

    def self.like_badge(count, is_topic)
      # we can do better with dates, but its hard work
"
    SELECT p.user_id, p.id post_id, p.updated_at granted_at
    FROM badge_posts p
    WHERE #{is_topic ? "p.post_number = 1" : "p.post_number > 1" } AND p.like_count >= #{count.to_i} AND
      (:backfill OR p.id IN (:post_ids) )
"
    end

    def self.trust_level(level)
      # we can do better with dates, but its hard work figuring this out historically
"
    SELECT u.id user_id, current_timestamp granted_at FROM users u
    WHERE trust_level >= #{level.to_i} AND (
      :backfill OR u.id IN (:user_ids)
    )
"
    end

    def self.sharing_badge(count)
<<SQL
    SELECT views.user_id, i2.post_id, i2.created_at granted_at
    FROM
    (
      SELECT i.user_id, MIN(i.id) i_id
      FROM incoming_links i
      JOIN badge_posts p on p.id = i.post_id
      WHERE i.user_id IS NOT NULL
      GROUP BY i.user_id,i.post_id
      HAVING COUNT(*) > #{count}
    ) as views
    JOIN incoming_links i2 ON i2.id = views.i_id
SQL
    end

    def self.linking_badge(count)
      <<-SQL
          SELECT tl.user_id, post_id, MIN(tl.created_at) granted_at
            FROM topic_links tl
            JOIN posts p  ON p.id = post_id    AND p.deleted_at IS NULL
            JOIN topics t ON t.id = p.topic_id AND t.deleted_at IS NULL AND t.archetype <> 'private_message'
           WHERE NOT tl.internal
             AND tl.clicks >= #{count}
        GROUP BY tl.user_id, tl.post_id
      SQL
    end

  end

  belongs_to :badge_type
  belongs_to :badge_grouping

  has_many :user_badges, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :badge_type, presence: true
  validates :allow_title, inclusion: [true, false]
  validates :multiple_grant, inclusion: [true, false]

  scope :enabled, ->{ where(enabled: true) }

  before_create :ensure_not_system

  # fields that can not be edited on system badges
  def self.protected_system_fields
    [:badge_type_id, :multiple_grant, :target_posts, :show_posts, :query, :trigger, :auto_revoke, :listable]
  end


  def self.trust_level_badge_ids
    (1..4).to_a
  end

  def self.like_badge_counts
    @like_badge_counts ||= {
      NicePost => 10,
      GoodPost => 25,
      GreatPost => 50,
      NiceTopic => 10,
      GoodTopic => 25,
      GreatTopic => 50
    }
  end

  def reset_grant_count!
    self.grant_count = UserBadge.where(badge_id: id).count
    save!
  end

  def single_grant?
    !self.multiple_grant?
  end

  def default_icon=(val)
    self.icon ||= val
    self.icon = val if self.icon = "fa-certificate"
  end

  def default_name=(val)
    self.name ||= val
  end

  def default_allow_title=(val)
    self.allow_title ||= val
  end

  def default_badge_grouping_id=(val)
    # allow to correct orphans
    if !self.badge_grouping_id || self.badge_grouping_id < 0
      self.badge_grouping_id = val
    end
  end

  def self.ensure_consistency!
    Badge.find_each(&:reset_grant_count!)
  end

  protected
  def ensure_not_system
    unless id
      self.id = [Badge.maximum(:id) + 1, 100].max
    end
  end
end

# == Schema Information
#
# Table name: badges
#
#  id                :integer          not null, primary key
#  name              :string(255)      not null
#  description       :text
#  badge_type_id     :integer          not null
#  grant_count       :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  allow_title       :boolean          default(FALSE), not null
#  multiple_grant    :boolean          default(FALSE), not null
#  icon              :string(255)      default("fa-certificate")
#  listable          :boolean          default(TRUE)
#  target_posts      :boolean          default(FALSE)
#  query             :text
#  enabled           :boolean          default(TRUE), not null
#  auto_revoke       :boolean          default(TRUE), not null
#  badge_grouping_id :integer          default(5), not null
#  trigger           :integer
#  show_posts        :boolean          default(FALSE), not null
#  system            :boolean          default(FALSE), not null
#  image             :string(255)
#  long_description  :text
#
# Indexes
#
#  index_badges_on_name  (name) UNIQUE
#
