class Badge < ActiveRecord::Base
  # NOTE: These badge ids are not in order! They are grouped logically. When picking an id
  # search for it.

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

  Appreciated = 36
  Respected = 37
  Admired = 31

  OutOfLove = 33
  HigherLove = 34
  CrazyInLove = 35

  ThankYou = 38
  GivesBack = 32
  Empathetic = 39

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
    PostProcessed = 16

    def self.is_none?(trigger)
      [None].include? trigger
    end

    def self.uses_user_ids?(trigger)
      [TrustLevelChange, UserChange, PostProcessed].include? trigger
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

  scope :enabled, ->{ where(enabled: true) }

  before_create :ensure_not_system

  # fields that can not be edited on system badges
  def self.protected_system_fields
    [
      :badge_type_id, :multiple_grant,
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
    exec_sql <<SQL
    DELETE FROM user_badges
    USING user_badges ub
    LEFT JOIN users u ON u.id = ub.user_id
    WHERE u.id IS NULL AND user_badges.id = ub.id
SQL

    Badge.find_each(&:reset_grant_count!)
  end

  def display_name
    key = "badges.#{i18n_name}.name"
    I18n.t(key, default: self.name)
  end

  def long_description
    key = "badges.#{i18n_name}.long_description"
    I18n.t(key, default: self[:long_description] || '')
  end

  def long_description=(val)
    if val != long_description
      self[:long_description] = val
    end

    val
  end

  def description
    key = "badges.#{i18n_name}.description"
    I18n.t(key, default: self[:description] || '')
  end

  def description=(val)
    if val != description
      self[:description] = val
    end

    val
  end


  def slug
    Slug.for(self.display_name, '-')
  end

  protected

  def ensure_not_system
    unless id
      self.id = [Badge.maximum(:id) + 1, 100].max
    end
  end

  def i18n_name
    self.name.downcase.gsub(' ', '_')
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
