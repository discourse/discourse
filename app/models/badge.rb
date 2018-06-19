require_dependency 'slug'

class Badge < ActiveRecord::Base
  # NOTE: These badge ids are not in order! They are grouped logically.
  #       When picking an id, *search* for it.

  BasicUser = 1
  Member = 2
  Regular = 3
  Leader = 4

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
  FirstMention = 40
  FirstEmoji = 41
  FirstOnebox = 42
  FirstReplyByEmail = 43

  ReadGuidelines = 16
  Reader = 17
  NiceTopic = 18
  GoodTopic = 19
  GreatTopic = 20
  NiceShare = 21
  GoodShare = 22
  GreatShare = 23
  Anniversary = 24

  Promoter = 25
  Campaigner = 26
  Champion = 27

  PopularLink = 28
  HotLink = 29
  FamousLink = 30

  Appreciated = 36
  Respected = 37
  Admired = 31

  OutOfLove = 33
  HigherLove = 34
  CrazyInLove = 35

  ThankYou = 38
  GivesBack = 32
  Empathetic = 39

  Enthusiast = 45
  Aficionado = 46
  Devotee = 47

  NewUserOfTheMonth = 44

  # other consts
  AutobiographerMinBioLength = 10

  # used by serializer
  attr_accessor :has_badge

  def self.trigger_hash
    Hash[*(
      Badge::Trigger.constants.map { |k|
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
    PostProcessed = 16 # deprecated

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

  belongs_to :badge_type
  belongs_to :badge_grouping

  has_many :user_badges, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :badge_type, presence: true
  validates :allow_title, inclusion: [true, false]
  validates :multiple_grant, inclusion: [true, false]

  scope :enabled, -> { where(enabled: true) }

  before_create :ensure_not_system

  # fields that can not be edited on system badges
  def self.protected_system_fields
    [
      :name, :badge_type_id, :multiple_grant,
      :target_posts, :show_posts, :query,
      :trigger, :auto_revoke, :listable
    ]
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

  def self.ensure_consistency!
    DB.exec <<~SQL
      DELETE FROM user_badges
            USING user_badges ub
        LEFT JOIN users u ON u.id = ub.user_id
            WHERE u.id IS NULL
              AND user_badges.id = ub.id
    SQL

    DB.exec <<~SQL
      WITH X AS (
          SELECT badge_id
               , COUNT(user_id) users
            FROM user_badges
        GROUP BY badge_id
      )
      UPDATE badges
         SET grant_count = X.users
        FROM X
       WHERE id = X.badge_id
         AND grant_count <> X.users
    SQL
  end

  def awarded_for_trust_level?
    id <= 4
  end

  def reset_grant_count!
    self.grant_count = UserBadge.where(badge_id: id).count
    save!
  end

  def single_grant?
    !self.multiple_grant?
  end

  def default_icon=(val)
    unless self.image
      self.icon ||= val
      self.icon = val if self.icon == "fa-certificate"
    end
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

  def display_name
    key = "badges.#{i18n_name}.name"
    I18n.t(key, default: self.name)
  end

  def long_description
    key = "badges.#{i18n_name}.long_description"
    I18n.t(key, default: self[:long_description] || '', base_uri: Discourse.base_uri)
  end

  def long_description=(val)
    self[:long_description] = val if val != long_description
    val
  end

  def description
    key = "badges.#{i18n_name}.description"
    I18n.t(key, default: self[:description] || '', base_uri: Discourse.base_uri)
  end

  def description=(val)
    self[:description] = val if val != description
    val
  end

  def slug
    Slug.for(self.display_name, '-')
  end

  def manually_grantable?
    query.blank? && !system?
  end

  protected

  def ensure_not_system
    self.id = [Badge.maximum(:id) + 1, 100].max unless id
  end

  def i18n_name
    self.name.downcase.tr(' ', '_')
  end

end

# == Schema Information
#
# Table name: badges
#
#  id                :integer          not null, primary key
#  name              :string           not null
#  description       :text
#  badge_type_id     :integer          not null
#  grant_count       :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  allow_title       :boolean          default(FALSE), not null
#  multiple_grant    :boolean          default(FALSE), not null
#  icon              :string           default("fa-certificate")
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
#  index_badges_on_badge_type_id  (badge_type_id)
#  index_badges_on_name           (name) UNIQUE
#
