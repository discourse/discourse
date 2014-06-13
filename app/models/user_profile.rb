class UserProfile < ActiveRecord::Base
  def upload_profile_background(upload)
    self.profile_background = upload.url
    self.save!
  end

  def clear_profile_background
    self.profile_background = ""
    self.save!
  end
end

# == Schema Information
#
# Table name: user_profiles
#
#  user_id                  :integer          not null, primary key
#  profile_background       :string(255)
#  location                 :string(255)
#  website                  :string(255)
#
