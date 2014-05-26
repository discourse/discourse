require_dependency 'letter_avatar'

class UserAvatar < ActiveRecord::Base
  MAX_SIZE = 240

  belongs_to :user
  belongs_to :system_upload, class_name: 'Upload', dependent: :destroy
  belongs_to :gravatar_upload, class_name: 'Upload', dependent: :destroy
  belongs_to :custom_upload, class_name: 'Upload', dependent: :destroy

  def contains_upload?(id)
    system_upload_id == id || gravatar_upload_id == id || custom_upload_id == id
  end

  # updates the letter based avatar
  def update_system_avatar!
    system_upload.destroy! if system_upload
    file = File.open(LetterAvatar.generate(user.username, MAX_SIZE), "r")
    self.system_upload = Upload.create_for(user_id, file, "avatar.png", file.size)
    save!
  end

  def update_gravatar!
    self.last_gravatar_download_attempt = Time.new
    gravatar_url = "http://www.gravatar.com/avatar/#{user.email_hash}.png?s=500&d=404"
    tempfile = FileHelper.download(gravatar_url, 1.megabyte, "gravatar")

    upload = Upload.create_for(user.id, tempfile, 'gravatar.png', File.size(tempfile.path))

    if gravatar_upload_id != upload.id
      gravatar_upload.try(:destroy!)
      self.gravatar_upload = upload
      save!
    else
      gravatar_upload
    end
    save!
  ensure
    tempfile.unlink if tempfile
  end

end

# == Schema Information
#
# Table name: user_avatars
#
#  id                             :integer          not null, primary key
#  user_id                        :integer          not null
#  system_upload_id               :integer
#  custom_upload_id               :integer
#  gravatar_upload_id             :integer
#  last_gravatar_download_attempt :datetime
#  created_at                     :datetime
#  updated_at                     :datetime
#
