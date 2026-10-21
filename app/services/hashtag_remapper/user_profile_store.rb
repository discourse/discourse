# frozen_string_literal: true

class HashtagRemapper
  class UserProfileStore < Store
    def self.key = "user_profile"
    def self.relation = UserProfile.all
    def self.raw_column = :bio_raw
    def self.cooked(profile) = profile.bio_cooked

    def self.write!(profile, raw)
      profile.skip_pull_hotlinked_image = true
      super
    end
  end
end
