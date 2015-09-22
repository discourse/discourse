require_dependency 'letter_avatar'

class UserAvatar < ActiveRecord::Base
  belongs_to :user
  belongs_to :gravatar_upload, class_name: 'Upload', dependent: :destroy
  belongs_to :custom_upload, class_name: 'Upload', dependent: :destroy

  def contains_upload?(id)
    gravatar_upload_id == id || custom_upload_id == id
  end

  def update_gravatar!
    DistributedMutex.synchronize("update_gravatar_#{user_id}") do
      begin
        # special logic for our system user
        email_hash = user_id == Discourse::SYSTEM_USER_ID ? User.email_hash("info@discourse.org") : user.email_hash

        self.last_gravatar_download_attempt = Time.new

        max = Discourse.avatar_sizes.max
        gravatar_url = "http://www.gravatar.com/avatar/#{email_hash}.png?s=#{max}&d=404"
        tempfile = FileHelper.download(gravatar_url, SiteSetting.max_image_size_kb.kilobytes, "gravatar")
        upload = Upload.create_for(user_id, tempfile, 'gravatar.png', File.size(tempfile.path), origin: gravatar_url, image_type: "avatar")

        if gravatar_upload_id != upload.id
          gravatar_upload.try(:destroy!) rescue nil
          self.gravatar_upload = upload
          save!
        end
      rescue OpenURI::HTTPError
        save!
      rescue SocketError
        # skip saving, we are not connected to the net
        Rails.logger.warn "Failed to download gravatar, socket error - user id #{user_id}"
      ensure
        tempfile.try(:close!)
      end
    end
  end

  def self.local_avatar_url(hostname, username, upload_id, size)
    self.local_avatar_template(hostname, username, upload_id).gsub("{size}", size.to_s)
  end

  def self.local_avatar_template(hostname, username, upload_id)
    version = self.version(upload_id)
    "#{Discourse.base_uri}/user_avatar/#{hostname}/#{username}/{size}/#{version}.png"
  end

  def self.external_avatar_url(user_id, upload_id, size)
    self.external_avatar_template(user_id, upload_id).gsub("{size}", size.to_s)
  end

  def self.external_avatar_template(user_id, upload_id)
    version = self.version(upload_id)
    "#{Discourse.store.absolute_base_url}/avatars/#{user_id}/{size}/#{version}.png"
  end

  def self.version(upload_id)
    "#{upload_id}_#{OptimizedImage::VERSION}"
  end

  def self.import_url_for_user(avatar_url, user)
    tempfile = FileHelper.download(avatar_url, SiteSetting.max_image_size_kb.kilobytes, "sso-avatar", true)

    ext = FastImage.type(tempfile).to_s
    tempfile.rewind

    upload = Upload.create_for(user.id, tempfile, "external-avatar." + ext, File.size(tempfile.path), origin: avatar_url, image_type: "avatar")
    user.uploaded_avatar_id = upload.id

    unless user.user_avatar
      user.build_user_avatar
    end

    if !user.user_avatar.contains_upload?(upload.id)
      user.user_avatar.custom_upload_id = upload.id
    end
  rescue => e
    # skip saving, we are not connected to the net
    Rails.logger.warn "#{e}: Failed to download external avatar: #{avatar_url}, user id #{ user.id }"
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
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#
# Indexes
#
#  index_user_avatars_on_user_id  (user_id)
#
