# frozen_string_literal: true

class Badge < ActiveRecord::Base
  include GlobalPath
  include HasSanitizableFields

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
  WikiEditor = 48

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
    @trigger_hash ||=
      Badge::Trigger
        .constants
        .map do |k|
          name = k.to_s.underscore
          [name, Badge::Trigger.const_get(k)] unless name =~ /deprecated/
        end
        .compact
        .to_h
  end

  module Trigger
    None = 0
    PostAction = 1
    PostRevision = 2
    TrustLevelChange = 4
    UserChange = 8
    DeprecatedPostProcessed = 16 # No longer in use

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
  belongs_to :image_upload, class_name: "Upload"

  has_many :user_badges, dependent: :destroy
  has_many :upload_references, as: :target, dependent: :destroy

  validates :name, presence: true, uniqueness: true, length: { maximum: 100 }
  validates :badge_type, presence: true
  validates :allow_title, inclusion: [true, false]
  validates :multiple_grant, inclusion: [true, false]
  validates :description, length: { maximum: 500 }
  validates :long_description, length: { maximum: 1000 }

  scope :enabled, -> { where(enabled: true) }

  before_create :ensure_not_system
  before_save :sanitize_description

  after_save do
    if saved_change_to_image_upload_id?
      UploadReference.ensure_exist!(upload_ids: [self.image_upload_id], target: self)
    end
  end

  after_commit do
    SvgSprite.expire_cache
    UserStat.update_distinct_badge_count if saved_change_to_enabled?
    UserBadge.ensure_consistency! if saved_change_to_enabled?
  end

  # fields that can not be edited on system badges
  def self.protected_system_fields
    %i[name badge_type_id multiple_grant target_posts show_posts query trigger auto_revoke listable]
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
      GreatTopic => 50,
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

  def clear_user_titles!
    DB.exec(<<~SQL, badge_id: self.id, updated_at: Time.zone.now)
      UPDATE users AS u
      SET title = '', updated_at = :updated_at
      FROM user_profiles AS up
      WHERE up.user_id = u.id AND up.granted_title_badge_id = :badge_id
    SQL
    DB.exec(<<~SQL, badge_id: self.id)
      UPDATE user_profiles AS up
      SET granted_title_badge_id = NULL
      WHERE up.granted_title_badge_id = :badge_id
    SQL
  end

  ##
  # Update all user titles based on a badge to the new name
  def update_user_titles!(new_title)
    DB.exec(<<~SQL, granted_title_badge_id: self.id, title: new_title, updated_at: Time.zone.now)
      UPDATE users AS u
      SET title = :title, updated_at = :updated_at
      FROM user_profiles AS up
      WHERE up.user_id = u.id AND up.granted_title_badge_id = :granted_title_badge_id
    SQL
  end

  ##
  # When a badge has its TranslationOverride cleared, reset
  # all user titles granted to the standard name.
  def reset_user_titles!
    DB.exec(<<~SQL, granted_title_badge_id: self.id, updated_at: Time.zone.now)
      UPDATE users AS u
      SET title = badges.name, updated_at = :updated_at
      FROM user_profiles AS up
      INNER JOIN badges ON badges.id = up.granted_title_badge_id
      WHERE up.user_id = u.id AND up.granted_title_badge_id = :granted_title_badge_id
    SQL
  end

  def self.i18n_name(name)
    name.to_s.downcase.tr(" ", "_")
  end

  def self.display_name(name)
    I18n.t(i18n_key(name), default: name)
  end

  def self.i18n_key(name)
    "badges.#{i18n_name(name)}.name"
  end

  def self.find_system_badge_id_from_translation_key(translation_key)
    return unless translation_key.starts_with?("badges.")
    badge_name_klass = translation_key.split(".").second.camelize
    Badge.const_defined?(badge_name_klass) ? "Badge::#{badge_name_klass}".constantize : nil
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
    if self.image_upload_id.blank?
      self.icon ||= val
      self.icon = val if self.icon == "fa-certificate"
    end
  end

  def default_allow_title=(val)
    return if !self.new_record?
    self.allow_title = val
  end

  def default_enabled=(val)
    return if !self.new_record?
    self.enabled = val
  end

  def default_badge_grouping_id=(val)
    # allow to correct orphans
    if !self.badge_grouping_id || self.badge_grouping_id <= BadgeGrouping::Other
      self.badge_grouping_id = val
    end
  end

  def display_name
    self.class.display_name(name)
  end

  def translation_key
    self.class.i18n_key(name)
  end

  def long_description
    key = "badges.#{i18n_name}.long_description"
    I18n.t(
      key,
      default: self[:long_description] || "",
      base_uri: Discourse.base_path,
      max_likes_per_day: SiteSetting.max_likes_per_day,
    )
  end

  def long_description=(val)
    self[:long_description] = val if val != long_description
  end

  def description
    key = "badges.#{i18n_name}.description"
    I18n.t(
      key,
      default: self[:description] || "",
      base_uri: Discourse.base_path,
      max_likes_per_day: SiteSetting.max_likes_per_day,
    )
  end

  def description=(val)
    self[:description] = val if val != description
  end

  def slug
    Slug.for(self.display_name, "-")
  end

  def manually_grantable?
    query.blank? && !system?
  end

  def i18n_name
    @i18n_name ||= self.class.i18n_name(name)
  end

  def image_url
    upload_cdn_path(image_upload.url) if image_upload_id.present?
  end

  def for_beginners?
    id == Welcome || (badge_grouping_id == BadgeGrouping::GettingStarted && id != NewUserOfTheMonth)
  end

  protected

  def ensure_not_system
    self.id = [Badge.maximum(:id) + 1, 100].max unless id
  end

  def sanitize_description
    self.description = sanitize_field(self.description) if description_changed?
  end
end

# == Schema Information
#
# Table name: badges
#
#  id                  :integer          not null, primary key
#  name                :string           not null
#  description         :text
#  badge_type_id       :integer          not null
#  grant_count         :integer          default(0), not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  allow_title         :boolean          default(FALSE), not null
#  multiple_grant      :boolean          default(FALSE), not null
#  icon                :string           default("fa-certificate")
#  listable            :boolean          default(TRUE)
#  target_posts        :boolean          default(FALSE)
#  query               :text
#  enabled             :boolean          default(TRUE), not null
#  auto_revoke         :boolean          default(TRUE), not null
#  badge_grouping_id   :integer          default(5), not null
#  trigger             :integer
#  show_posts          :boolean          default(FALSE), not null
#  system              :boolean          default(FALSE), not null
#  show_in_post_header :boolean          default(FALSE), not null
#  long_description    :text
#  image_upload_id     :integer
#
# Indexes
#
#  index_badges_on_badge_type_id  (badge_type_id)
#  index_badges_on_name           (name) UNIQUE
#
