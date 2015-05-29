require_dependency 'letter_avatar'

class UserAvatar < ActiveRecord::Base
  belongs_to :user
  belongs_to :gravatar_upload, class_name: 'Upload', dependent: :destroy
  belongs_to :custom_upload, class_name: 'Upload', dependent: :destroy

  def contains_upload?(id)
    gravatar_upload_id == id || custom_upload_id == id
  end

  def update_gravatar!
    DistributedMutex.synchronize("update_gravatar_#{user.id}") do
      begin
        # special logic for our system user
        email_hash = user.id == Discourse::SYSTEM_USER_ID ? User.email_hash("info@discourse.org") : user.email_hash

        self.last_gravatar_download_attempt = Time.new

        size = Discourse.avatar_sizes.max
        gravatar_url = "http://www.gravatar.com/avatar/#{email_hash}.png?s=#{size}&d=404"
        tempfile = FileHelper.download(gravatar_url, SiteSetting.max_image_size_kb.kilobytes, "gravatar")
        upload = Upload.create_for(user.id, tempfile, 'gravatar.png', tempfile.size, { origin: gravatar_url })

        if gravatar_upload_id != upload.id
          gravatar_upload.try(:destroy!)
          self.gravatar_upload = upload
          save!
        end
      rescue OpenURI::HTTPError
        save!
      rescue SocketError
        # skip saving, we are not connected to the net
        Rails.logger.warn "Failed to download gravatar, socket error - user id #{user.id}"
      ensure
        tempfile.try(:close!)
      end
    end
  end

  def self.cache_avatars(limit)
    return unless Discourse.store.external?

    UserAvatar.includes(:custom_upload, :user)
              .joins("INNER JOIN uploads ON uploads.id = user_avatars.custom_upload_id")
              .where("uploads.url LIKE '#{Discourse.store.absolute_base_url}%'")
              .where(is_cached: false)
              .order(updated_at: :desc)
              .limit(limit)
              .first(limit)
              .each do |user_avatar|
      begin
        # create thumbnails
        self.create_thumbnails(user_avatar.custom_upload, user_avatar.user)
      rescue
        Rails.logger.error("Failed to create thumbnails for user_avatar ##{user_avatar.id}")
      end
    end
  end

  def self.create_thumbnails(upload, user)
    DistributedMutex.synchronize("#{upload.id}-#{user.id}") do
      if Discourse.store.external?
        user.user_avatar.update_attributes(is_cached: false)
      end

      Discourse.avatar_sizes.each do |size|
        avatar = OptimizedImage.create_for(upload, size, size, allow_animation: SiteSetting.allow_animated_avatars)
        Discourse.store.cache_avatar(avatar, user.id)
      end

      if Discourse.store.external?
        user.user_avatar.update_attributes(is_cached: true)
      end
    end
  end

  def self.local_avatar_url(hostname, username, upload_id, size)
    version = self.version(upload_id)
    "#{Discourse.base_uri}/user_avatar/#{hostname}/#{username}/#{size}/#{version}.png"
  end

  def self.local_avatar_template(hostname, username, upload_id)
    version = self.version(upload_id)
    "#{Discourse.base_uri}/user_avatar/#{hostname}/#{username}/{size}/#{version}.png"
  end

  def self.external_avatar_url(user_id, upload_id, size)
    version = self.version(upload_id)
    "#{Discourse.store.absolute_base_url}/avatars/#{user_id}/#{size}/#{version}.png"
  end

  def self.external_avatar_template(user_id, upload_id)
    version = self.version(upload_id)
    "#{Discourse.store.absolute_base_url}/avatars/#{user_id}/{size}/#{version}.png"
  end

  def self.version(upload_id)
    "#{upload_id}_#{OptimizedImage::VERSION}"
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
