# frozen_string_literal: true

class UserAvatar < ActiveRecord::Base
  UPLOAD_ID_COLUMNS = %i[gravatar_upload_id custom_upload_id].freeze

  belongs_to :user
  belongs_to :gravatar_upload, class_name: "Upload"
  belongs_to :custom_upload, class_name: "Upload"
  has_many :upload_references, as: :target, dependent: :destroy

  after_save do
    if saved_change_to_custom_upload_id? || saved_change_to_gravatar_upload_id?
      upload_ids = [custom_upload_id, gravatar_upload_id]
      UploadReference.ensure_exist!(upload_ids: upload_ids, target: self)
    end
  end

  @@custom_user_gravatar_email_hash = {
    Discourse::SYSTEM_USER_ID => User.email_hash("info@discourse.org"),
  }

  def contains_upload?(id)
    gravatar_upload_id == id || custom_upload_id == id
  end

  def custom_avatar_template
    return unless custom_upload_id

    User.avatar_template(user.username, custom_upload_id)
  end

  def pick_associated_account(account_id)
    user.with_lock do
      account = user.user_associated_accounts.lock.find_by(id: account_id)
      return false unless account&.avatar_upload && account.authenticator

      reload
      update!(selected_user_associated_account_id: account.id)
      user.update!(uploaded_avatar_id: account.avatar_upload_id)
    end

    true
  end

  def update_gravatar!(selection: :preserve)
    DistributedMutex.synchronize("update_gravatar_#{user_id}") do
      update!(last_gravatar_download_attempt: Time.zone.now)
      return if user&.primary_email.blank?

      upload = download_gravatar!

      user.with_lock do
        reload
        selected_gravatar = gravatar_upload_id && user.uploaded_avatar_id == gravatar_upload_id
        select_if_missing = selection == :if_missing && !user.uploaded_avatar_id
        update!(gravatar_upload: upload) if upload && gravatar_upload_id != upload.id

        return if selected_user_associated_account_id || !gravatar_upload_id
        return unless selected_gravatar || select_if_missing
        return if user.uploaded_avatar_id == gravatar_upload_id

        user.update!(uploaded_avatar_id: gravatar_upload_id)
      end
    end
  end

  def self.register_custom_user_gravatar_email_hash(user_id, email)
    @@custom_user_gravatar_email_hash[user_id] = User.email_hash(email)
  end

  def self.find_upload_for_user(user, upload_id)
    return user.uploaded_avatar if user.uploaded_avatar_id == upload_id
    return unless avatar = user.user_avatar
    return Upload.find_by(id: upload_id) if avatar.contains_upload?(upload_id)

    user.user_associated_accounts.find_by(avatar_upload_id: upload_id)&.avatar_upload
  end

  def self.pick_for_user!(user, upload_id, type: :current)
    user.with_lock do
      avatar = user.user_avatar || user.build_user_avatar
      avatar.gravatar_upload_id = upload_id if type == :gravatar
      avatar.custom_upload_id = upload_id if %i[uploaded custom].include?(type)
      avatar.selected_user_associated_account_id = nil
      avatar.save!
      user.update!(uploaded_avatar_id: upload_id)
    end
  end

  def self.remove_for_user!(user)
    return false if user.uploaded_avatar_id.blank?

    user.with_lock do
      user.update!(uploaded_avatar_id: nil)
      user.user_avatar&.update!(
        custom_upload_id: nil,
        gravatar_upload_id: nil,
        selected_user_associated_account_id: nil,
      )
      user
        .user_associated_accounts
        .where.not(avatar_upload_id: nil)
        .each { |account| account.update!(avatar_upload_id: nil) }
    end

    true
  end

  def self.assign_random_to_user(user)
    return unless SiteSetting.selectable_avatars_random_on_signup
    return if SiteSetting.selectable_avatars_mode == "disabled"
    return unless upload = SiteSetting.selectable_avatars.sample

    user.update_column(:uploaded_avatar_id, upload.id)
    UploadReference.ensure_exist!(upload_ids: [upload.id], target: user)
  end

  def self.retrieve_for_associated_account(account, selection: :preserve)
    user = account.user
    url = account.info["image"]
    return unless user && url.present?

    user.with_lock do
      avatar = user.user_avatar || user.create_user_avatar!
      if SiteSetting.auth_overrides_avatar ||
           (selection == :initial && user.uploaded_avatar_id.nil? && avatar.custom_upload_id.nil?)
        avatar.update!(selected_user_associated_account_id: account.id)
      end
    end

    Jobs.enqueue(
      :download_avatar_from_url,
      url: url,
      user_id: user.id,
      associated_account_id: account.id,
    )
  end

  def self.refresh_for_user(user)
    avatar = user.user_avatar || user.create_user_avatar

    if user.primary_email.present? && SiteSetting.automatically_download_gravatars? &&
         !avatar.last_gravatar_download_attempt
      Jobs.cancel_scheduled_job(:update_gravatar, user_id: user.id, avatar_id: avatar.id)
      Jobs.enqueue_in(1.second, :update_gravatar, user_id: user.id, avatar_id: avatar.id)
    end

    if user.saved_change_to_uploaded_avatar_id?
      Jobs.enqueue(:rebake_quoted_posts_for_user, user_id: user.id)
    end
  end

  def self.import_url_for_user(avatar_url, user, options = nil)
    if account_id = options&.[](:associated_account_id)
      return import_associated_account_avatar(avatar_url, user, account_id)
    end

    upload = download_for_user(avatar_url, user, options)
    return unless upload&.persisted?

    user.with_lock do
      avatar = user.user_avatar || user.build_user_avatar
      cached_upload = avatar.contains_upload?(upload.id)
      override_gravatar = !options || options[:override_gravatar]
      return if cached_upload && !override_gravatar

      avatar.custom_upload_id = upload.id unless cached_upload
      replace_current =
        !user.uploaded_avatar_id || !avatar.contains_upload?(user.uploaded_avatar_id) ||
          override_gravatar
      avatar.selected_user_associated_account_id = nil if replace_current
      avatar.save!

      user.update!(uploaded_avatar_id: upload.id) if replace_current
    end
  end

  def self.local_avatar_url(hostname, username, upload_id, size)
    local_avatar_template(hostname, username, upload_id).gsub("{size}", size.to_s)
  end

  def self.local_avatar_template(hostname, username, upload_id)
    version = self.version(upload_id)
    "#{Discourse.base_path}/user_avatar/#{hostname}/#{username}/{size}/#{version}.png"
  end

  def self.external_avatar_url(user_id, upload_id, size)
    external_avatar_template(user_id, upload_id).gsub("{size}", size.to_s)
  end

  def self.external_avatar_template(user_id, upload_id)
    version = self.version(upload_id)
    "#{Discourse.store.absolute_base_url}/avatars/#{user_id}/{size}/#{version}.png"
  end

  def self.version(upload_id)
    "#{upload_id}_#{OptimizedImage::VERSION}"
  end

  def self.clear_associated_account_selection(account_ids, except_user_id: nil)
    where(selected_user_associated_account_id: account_ids)
      .where.not(user_id: except_user_id)
      .update_all(selected_user_associated_account_id: nil)
  end

  def self.remove_upload(upload_id)
    User.where(uploaded_avatar_id: upload_id).update_all(uploaded_avatar_id: nil)
    UPLOAD_ID_COLUMNS.each { |column| where(column => upload_id).update_all(column => nil) }

    accounts = UserAssociatedAccount.where(avatar_upload_id: upload_id)
    clear_associated_account_selection(accounts.select(:id))
    accounts.update_all(avatar_upload_id: nil)
  end

  def self.ensure_consistency!(max_optimized_avatars_to_remove: 20_000)
    DB.exec <<~SQL
      DELETE FROM user_avatars
      USING user_avatars ua
      LEFT JOIN users u ON ua.user_id = u.id
      WHERE user_avatars.id = ua.id AND u.id IS NULL
    SQL

    UPLOAD_ID_COLUMNS.each { |column| DB.exec <<~SQL }
        UPDATE user_avatars
        SET #{column} = NULL
        WHERE #{column} IN (
          SELECT ua.#{column} FROM user_avatars ua
          LEFT JOIN uploads up ON ua.#{column} = up.id
          WHERE ua.#{column} IS NOT NULL AND up.id IS NULL
        )
      SQL

    ids =
      DB.query_single(<<~SQL, sizes: Discourse.avatar_sizes, limit: max_optimized_avatars_to_remove)
      SELECT oi.id FROM (
        SELECT custom_upload_id FROM user_avatars
        EXCEPT
        SELECT upload_id FROM  upload_references WHERE target_type <> 'UserAvatar'
        AND upload_id IS NOT NULL
      ) AS a
      JOIN optimized_images oi ON oi.upload_id = a.custom_upload_id
      WHERE oi.width not in (:sizes) AND oi.height not in (:sizes)
      LIMIT :limit
    SQL

    warnings_reported = 0

    ids.each do |id|
      OptimizedImage.find(id).destroy!
    rescue ActiveRecord::RecordNotFound
    rescue => e
      if warnings_reported < 10
        Discourse.warn_exception(e, message: "Failed to remove optimized image")
        warnings_reported += 1
      end
    end
  end

  def self.import_associated_account_avatar(url, user, account_id)
    account = user.user_associated_accounts.find_by(id: account_id)
    return unless account && account.info["image"] == url

    upload = download_for_user(url, user)
    return unless upload&.persisted?

    user.with_lock do
      account = user.user_associated_accounts.lock.find_by(id: account_id)
      return unless account && account.info["image"] == url

      account.update!(avatar_upload: upload)

      if user.user_avatar&.selected_user_associated_account_id == account.id &&
           account.authenticator
        user.update!(uploaded_avatar_id: upload.id)
      end
    end
  end
  private_class_method :import_associated_account_avatar

  def self.download_for_user(avatar_url, user, options = nil)
    if SiteSetting.verbose_upload_logging
      Rails.logger.warn("Verbose Upload Logging: Downloading sso-avatar from #{avatar_url}")
    end

    tempfile =
      FileHelper.download(
        avatar_url,
        max_file_size: SiteSetting.max_image_size_kb.kilobytes,
        tmp_file_name: "sso-avatar",
        follow_redirect: true,
        skip_rate_limit: !!options&.fetch(:skip_rate_limit, false),
      )

    return unless tempfile

    ext = FastImage.type(tempfile).to_s
    tempfile.rewind

    UploadCreator.new(
      tempfile,
      "external-avatar." + ext,
      origin: avatar_url,
      type: "avatar",
    ).create_for(user.id)
  rescue Net::ReadTimeout, OpenURI::HTTPError, FinalDestination::SSRFError
    # Skip saving. We are not connected to the net, or SSRF checks failed.
  ensure
    tempfile.close! if tempfile && tempfile.respond_to?(:close!)
  end
  private_class_method :download_for_user

  private

  def download_gravatar!
    max = Discourse.avatar_sizes.max
    email_hash = @@custom_user_gravatar_email_hash[user_id] || user.email_hash
    gravatar_url =
      "https://#{SiteSetting.gravatar_base_url}/avatar/#{email_hash}.png?s=#{max}&d=404&reset_cache=#{SecureRandom.urlsafe_base64(5)}"

    if SiteSetting.verbose_upload_logging
      Rails.logger.warn("Verbose Upload Logging: Downloading gravatar from #{gravatar_url}")
    end

    tempfile =
      FileHelper.download(
        gravatar_url,
        max_file_size: SiteSetting.max_image_size_kb.kilobytes,
        tmp_file_name: "gravatar",
        skip_rate_limit: true,
        verbose: false,
        follow_redirect: true,
      )

    return unless tempfile

    ext = File.extname(tempfile).presence || ".png"
    UploadCreator.new(
      tempfile,
      "gravatar#{ext}",
      origin: gravatar_url,
      type: "avatar",
      for_gravatar: true,
    ).create_for(user_id)
  rescue OpenURI::HTTPError => e
    raise e if e.io&.status&.[](0).to_i != 404
  ensure
    tempfile&.close!
  end
end

# == Schema Information
#
# Table name: user_avatars
#
#  id                                  :integer          not null, primary key
#  last_gravatar_download_attempt      :datetime
#  created_at                          :datetime         not null
#  updated_at                          :datetime         not null
#  custom_upload_id                    :integer
#  gravatar_upload_id                  :integer
#  selected_user_associated_account_id :bigint
#  user_id                             :integer          not null
#
# Indexes
#
#  index_user_avatars_on_custom_upload_id                     (custom_upload_id)
#  index_user_avatars_on_gravatar_upload_id                   (gravatar_upload_id)
#  index_user_avatars_on_selected_user_associated_account_id  (selected_user_associated_account_id) WHERE (selected_user_associated_account_id IS NOT NULL)
#  index_user_avatars_on_user_id                              (user_id)
#
