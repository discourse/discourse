class UserProfileView < ActiveRecord::Base
  validates :user_profile_id, presence: true
  validates :viewed_at, presence: true
  validates :ip_address, presence: true
end
