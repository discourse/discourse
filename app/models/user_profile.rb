class UserProfile < ActiveRecord::Base
  belongs_to :user, inverse_of: :user_profile

  validates :user, presence: true
  before_save :cook
  after_save :assign_autobiographer

  def bio_excerpt
    excerpt = PrettyText.excerpt(bio_cooked, 350)
    return excerpt if excerpt.blank? || user.has_trust_level?(:basic)
    PrettyText.strip_links(excerpt)
  end

  def bio_processed
    return bio_cooked if bio_cooked.blank? || user.has_trust_level?(:basic)
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

  def upload_profile_background(upload)
    self.profile_background = upload.url
    self.save!
  end

  def clear_profile_background
    self.profile_background = ""
    self.save!
  end

  protected

  def assign_autobiographer
    if bio_raw_changed?
      user.grant_autobiographer
    end
  end

  private

  def cook
    if self.bio_raw.present?
      self.bio_cooked = PrettyText.cook(self.bio_raw, omit_nofollow: user.has_trust_level?(:leader)) if bio_raw_changed?
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
#
