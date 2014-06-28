require_dependency 'letter_avatar'

class UserAvatar < ActiveRecord::Base
  MAX_SIZE = 240

  belongs_to :user
  belongs_to :gravatar_upload, class_name: 'Upload', dependent: :destroy
  belongs_to :custom_upload, class_name: 'Upload', dependent: :destroy

  def contains_upload?(id)
    gravatar_upload_id == id || custom_upload_id == id
  end

  def update_gravatar!
    # special logic for our system user, we do not want the discourse email there
    email_hash = user.id == -1 ? User.email_hash("info@discourse.org") : user.email_hash

    self.last_gravatar_download_attempt = Time.new
    gravatar_url = "http://www.gravatar.com/avatar/#{email_hash}.png?s=500&d=404"
    tempfile = FileHelper.download(gravatar_url, 1.megabyte, "gravatar")

    upload = Upload.create_for(user.id, tempfile, 'gravatar.png', File.size(tempfile.path))

    if gravatar_upload_id != upload.id
      gravatar_upload.try(:destroy!)
      self.gravatar_upload = upload
      save!
    else
      gravatar_upload
    end
  rescue OpenURI::HTTPError
    save!
  rescue SocketError
    # skip saving, we are not connected to the net
    Rails.logger.warn "Failed to download gravatar, socket error - user id #{ user.id }"
  ensure
    tempfile.close! if tempfile && tempfile.respond_to?(:close!)
  end

end

# == Schema Information
#
# Table name: user_avatars
#
#  id                             :integer          not null, primary key
#  user_id                        :integer          not null
#  custom_upload_id               :integer
#  gravatar_upload_id             :integer
#  last_gravatar_download_attempt :datetime
#  created_at                     :datetime
#  updated_at                     :datetime
#
# Indexes
#
#  index_user_avatars_on_user_id  (user_id)
#
