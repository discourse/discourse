# frozen_string_literal: true

class UserProfile < ActiveRecord::Base
  belongs_to :user, inverse_of: :user_profile
  belongs_to :card_background_upload, class_name: "Upload"
  belongs_to :profile_background_upload, class_name: "Upload"
  belongs_to :granted_title_badge, class_name: "Badge"
  belongs_to :featured_topic, class_name: 'Topic'

  validates :bio_raw, length: { maximum: 3000 }
  validates :website, url: true, allow_blank: true, if: Proc.new { |c| c.new_record? || c.website_changed? }
  validates :user, presence: true
  before_save :cook
  after_save :trigger_badges

  validate :website_domain_validator, if: Proc.new { |c| c.new_record? || c.website_changed? }

  has_many :user_profile_views, dependent: :destroy

  BAKED_VERSION = 1

  def bio_excerpt(length = 350, opts = {})
    return nil if bio_cooked.blank?
    excerpt = PrettyText.excerpt(bio_cooked, length, opts).sub(/<br>$/, '')
    return excerpt if excerpt.blank? || (user.has_trust_level?(TrustLevel[1]) && !user.suspended?)
    PrettyText.strip_links(excerpt)
  end

  def bio_processed
    return bio_cooked if bio_cooked.blank? || (user.has_trust_level?(TrustLevel[1]) && !user.suspended?)
    PrettyText.strip_links(bio_cooked)
  end

  def bio_summary
    bio_excerpt(500, strip_links: true, text_entities: true)
  end

  def recook_bio
    self.bio_raw_will_change!
    cook
  end

  def upload_card_background(upload)
    self.update!(card_background_upload: upload)
  end

  def clear_card_background
    self.update!(card_background_upload: nil)
  end

  def upload_profile_background(upload)
    self.update!(profile_background_upload: upload)
  end

  def clear_profile_background
    self.update!(profile_background_upload: nil)
  end

  def self.rebake_old(limit)
    problems = []
    UserProfile.where('bio_cooked_version IS NULL OR bio_cooked_version < ?', BAKED_VERSION)
      .limit(limit).each do |p|
      begin
        p.rebake!
      rescue => e
        problems << { profile: p, ex: e }
      end
    end
    problems
  end

  def rebake!
    update_columns(bio_cooked: cooked, bio_cooked_version: BAKED_VERSION)
  end

  def self.import_url_for_user(background_url, user, options = nil)
    tempfile = FileHelper.download(
      background_url,
      max_file_size: SiteSetting.max_image_size_kb.kilobytes,
      tmp_file_name: "sso-profile-background",
      follow_redirect: true
    )

    return unless tempfile

    ext = FastImage.type(tempfile).to_s
    tempfile.rewind

    is_card_background = !options || options[:is_card_background]
    type = is_card_background ? "card_background" : "profile_background"

    upload = UploadCreator.new(tempfile, "external-profile-background." + ext, origin: background_url, type: type).create_for(user.id)

    if (is_card_background)
      user.user_profile.upload_card_background(upload)
    else
      user.user_profile.upload_profile_background(upload)
    end

  rescue Net::ReadTimeout, OpenURI::HTTPError
    # skip saving, we are not connected to the net
  ensure
    tempfile.close! if tempfile && tempfile.respond_to?(:close!)
  end

  protected

  def trigger_badges
    BadgeGranter.queue_badge_grant(Badge::Trigger::UserChange, user: self)
  end

  private

  def cooked
    if self.bio_raw.present?
      PrettyText.cook(self.bio_raw, omit_nofollow: user.has_trust_level?(TrustLevel[3]) && !SiteSetting.tl3_links_no_follow)
    else
      nil
    end
  end

  def cook
    if self.bio_raw.present?
      if bio_raw_changed?
        self.bio_cooked = cooked
        self.bio_cooked_version = BAKED_VERSION
      end
    else
      self.bio_cooked = nil
    end
  end

  def website_domain_validator
    allowed_domains = SiteSetting.user_website_domains_whitelist
    return if (allowed_domains.blank? || self.website.blank?)

    domain = begin
      URI.parse(self.website).host
    rescue URI::Error
    end
    self.errors.add :base, (I18n.t('user.website.domain_not_allowed', domains: allowed_domains.split('|').join(", "))) unless allowed_domains.split('|').include?(domain)
  end

  def self.remove_featured_topic_from_all_profiles(topic)
    where(featured_topic_id: topic.id).update_all(featured_topic_id: nil)
  end
end

# == Schema Information
#
# Table name: user_profiles
#
#  user_id                      :integer          not null, primary key
#  location                     :string
#  website                      :string
#  bio_raw                      :text
#  bio_cooked                   :text
#  dismissed_banner_key         :integer
#  bio_cooked_version           :integer
#  badge_granted_title          :boolean          default(FALSE)
#  views                        :integer          default(0), not null
#  profile_background_upload_id :integer
#  card_background_upload_id    :integer
#  granted_title_badge_id       :bigint
#  featured_topic_id            :integer
#
# Indexes
#
#  index_user_profiles_on_bio_cooked_version            (bio_cooked_version)
#  index_user_profiles_on_card_background_upload_id     (card_background_upload_id)
#  index_user_profiles_on_granted_title_badge_id        (granted_title_badge_id)
#  index_user_profiles_on_profile_background_upload_id  (profile_background_upload_id)
#
# Foreign Keys
#
#  fk_rails_...  (card_background_upload_id => uploads.id)
#  fk_rails_...  (granted_title_badge_id => badges.id)
#  fk_rails_...  (profile_background_upload_id => uploads.id)
#
