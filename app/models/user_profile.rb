class UserProfile < ActiveRecord::Base
  belongs_to :user, inverse_of: :user_profile

  validates :bio_raw, length: { maximum: 3000 }
  validates :user, presence: true
  before_save :cook
  after_save :trigger_badges

  belongs_to :card_image_badge, class_name: 'Badge'

  BAKED_VERSION = 1

  def bio_excerpt
    excerpt = PrettyText.excerpt(bio_cooked, 350)
    return excerpt if excerpt.blank? || user.has_trust_level?(TrustLevel[1])
    PrettyText.strip_links(excerpt)
  end

  def bio_processed
    return bio_cooked if bio_cooked.blank? || user.has_trust_level?(TrustLevel[1])
    PrettyText.strip_links(bio_cooked)
  end

  def bio_summary
    return nil unless bio_cooked.present?
    Summarize.new(bio_cooked).summary
  end

  def recook_bio
    self.bio_raw_will_change!
    cook
  end

  def upload_card_background(upload)
    self.card_background = upload.url
    self.save!
  end

  def clear_card_background
    self.card_background = ""
    self.save!
  end

  def upload_profile_background(upload)
    self.profile_background = upload.url
    self.save!
  end

  def clear_profile_background
    self.profile_background = ""
    self.save!
  end

  def self.rebake_old(limit)
    problems = []
    UserProfile.where('bio_cooked_version IS NULL OR bio_cooked_version < ?', BAKED_VERSION)
        .limit(limit).each do |p|
      begin
        p.rebake!
      rescue => e
        problems << {profile: p, ex: e}
      end
    end
    problems
  end

  def rebake!
    update_columns(bio_cooked: cooked, bio_cooked_version: BAKED_VERSION)
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

end

# == Schema Information
#
# Table name: user_profiles
#
#  user_id              :integer          not null, primary key
#  location             :string(255)
#  website              :string(255)
#  bio_raw              :text
#  bio_cooked           :text
#  dismissed_banner_key :integer
#  profile_background   :string(255)
#  card_background      :string(255)
#  bio_cooked_version   :integer
#
# Indexes
#
#  index_user_profiles_on_bio_cooked_version  (bio_cooked_version)
#
