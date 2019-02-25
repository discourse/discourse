require_dependency 'letter_avatar'
require_dependency 'upload_creator'

class UserAvatar < ActiveRecord::Base
  belongs_to :user
  belongs_to :gravatar_upload, class_name: 'Upload'
  belongs_to :custom_upload, class_name: 'Upload'

  def contains_upload?(id)
    gravatar_upload_id == id || custom_upload_id == id
  end

  def update_gravatar!
    DistributedMutex.synchronize("update_gravatar_#{user_id}") do
      begin
        self.update!(last_gravatar_download_attempt: Time.now)

        max = Discourse.avatar_sizes.max
        email_hash = user_id == Discourse::SYSTEM_USER_ID ? User.email_hash("info@discourse.org") : user.email_hash
        gravatar_url = "https://www.gravatar.com/avatar/#{email_hash}.png?s=#{max}&d=404"

        # follow redirects in case gravatar change rules on us
        tempfile = FileHelper.download(
          gravatar_url,
          max_file_size: SiteSetting.max_image_size_kb.kilobytes,
          tmp_file_name: "gravatar",
          skip_rate_limit: true,
          verbose: false,
          follow_redirect: true
        )

        if tempfile
          ext = File.extname(tempfile)
          ext = '.png' if ext.blank?

          upload = UploadCreator.new(
            tempfile,
            "gravatar#{ext}",
            origin: gravatar_url,
            type: "avatar"
          ).create_for(user_id)

          if gravatar_upload_id != upload.id
            User.transaction do
              if gravatar_upload_id && user.uploaded_avatar_id == gravatar_upload_id
                user.update!(uploaded_avatar_id: upload.id)
              end

              self.update!(gravatar_upload: upload)
            end
          end
        end
      rescue OpenURI::HTTPError => e
        if e.io&.status[0].to_i != 404
          raise e
        end
      ensure
        tempfile&.close!
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

  def self.import_url_for_user(avatar_url, user, options = nil)
    tempfile = FileHelper.download(
      avatar_url,
      max_file_size: SiteSetting.max_image_size_kb.kilobytes,
      tmp_file_name: "sso-avatar",
      follow_redirect: true
    )

    return unless tempfile

    ext = FastImage.type(tempfile).to_s
    tempfile.rewind

    upload = UploadCreator.new(tempfile, "external-avatar." + ext, origin: avatar_url, type: "avatar").create_for(user.id)

    user.create_user_avatar! unless user.user_avatar

    if !user.user_avatar.contains_upload?(upload.id)
      user.user_avatar.update!(custom_upload_id: upload.id)
      override_gravatar = !options || options[:override_gravatar]

      if user.uploaded_avatar_id.nil? ||
          !user.user_avatar.contains_upload?(user.uploaded_avatar_id) ||
          override_gravatar

        user.update!(uploaded_avatar_id: upload.id)
      end
    end

  rescue Net::ReadTimeout, OpenURI::HTTPError
    # skip saving, we are not connected to the net
  ensure
    tempfile.close! if tempfile && tempfile.respond_to?(:close!)
  end

  def self.ensure_consistency!
    DB.exec <<~SQL
      UPDATE user_avatars
      SET gravatar_upload_id = NULL
      WHERE gravatar_upload_id IN (
        SELECT u1.gravatar_upload_id FROM user_avatars u1
        LEFT JOIN uploads up
          ON u1.gravatar_upload_id = up.id
        WHERE u1.gravatar_upload_id IS NOT NULL AND
          up.id IS NULL
      )
    SQL

    DB.exec <<~SQL
      UPDATE user_avatars
      SET custom_upload_id = NULL
      WHERE custom_upload_id IN (
        SELECT u1.custom_upload_id FROM user_avatars u1
        LEFT JOIN uploads up
          ON u1.custom_upload_id = up.id
        WHERE u1.custom_upload_id IS NOT NULL AND
          up.id IS NULL
      )
    SQL
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
#  index_user_avatars_on_custom_upload_id    (custom_upload_id)
#  index_user_avatars_on_gravatar_upload_id  (gravatar_upload_id)
#  index_user_avatars_on_user_id             (user_id)
#
