# frozen_string_literal: true

require "digest/sha1"

class Upload < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include HasUrl

  SHA1_LENGTH = 40
  SEEDED_ID_THRESHOLD = 0
  URL_REGEX = %r{(/original/\dX[/\.\w]*/(\h+)[\.\w]*)}
  MAX_IDENTIFY_SECONDS = 5
  DOMINANT_COLOR_COMMAND_TIMEOUT_SECONDS = 5

  belongs_to :user
  belongs_to :access_control_post, class_name: "Post"

  # when we access this post we don't care if the post
  # is deleted
  def access_control_post
    Post.unscoped { super }
  end

  has_many :post_hotlinked_media, dependent: :destroy, class_name: "PostHotlinkedMedia"
  has_many :optimized_images, dependent: :destroy
  has_many :user_uploads, dependent: :destroy
  has_many :upload_references, dependent: :destroy
  has_many :posts, through: :upload_references, source: :target, source_type: "Post"
  has_many :topic_thumbnails
  has_many :badges, foreign_key: :image_upload_id, dependent: :nullify

  attr_accessor :for_group_message
  attr_accessor :for_theme
  attr_accessor :for_private_message
  attr_accessor :for_export
  attr_accessor :for_site_setting
  attr_accessor :for_gravatar
  attr_accessor :validate_file_size

  validates_presence_of :filesize
  validates_presence_of :original_filename
  validates :dominant_color, length: { is: 6 }, allow_blank: true, allow_nil: true

  validates_with UploadValidator

  before_destroy do
    UserProfile.where(card_background_upload_id: self.id).update_all(card_background_upload_id: nil)
    UserProfile.where(profile_background_upload_id: self.id).update_all(
      profile_background_upload_id: nil,
    )
  end

  after_destroy do
    User.where(uploaded_avatar_id: self.id).update_all(uploaded_avatar_id: nil)
    UserAvatar.where(gravatar_upload_id: self.id).update_all(gravatar_upload_id: nil)
    UserAvatar.where(custom_upload_id: self.id).update_all(custom_upload_id: nil)
  end

  scope :by_users, -> { where("uploads.id > ?", SEEDED_ID_THRESHOLD) }

  scope :without_s3_file_missing_confirmed_verification_status,
        -> do
          where.not(verification_status: Upload.verification_statuses[:s3_file_missing_confirmed])
        end

  scope :with_invalid_etag_verification_status,
        -> { where(verification_status: Upload.verification_statuses[:invalid_etag]) }

  def self.verification_statuses
    @verification_statuses ||=
      Enum.new(
        unchecked: 1,
        verified: 2,
        invalid_etag: 3, # Used by S3Inventory to mark S3 Upload records that have an invalid ETag value compared to the ETag value of the inventory file
        s3_file_missing_confirmed: 4, # Used by S3Inventory to skip S3 Upload records that are confirmed to not be backed by a file in the S3 file store
      )
  end

  def self.mark_invalid_s3_uploads_as_missing
    Upload.with_invalid_etag_verification_status.update_all(
      verification_status: Upload.verification_statuses[:s3_file_missing_confirmed],
    )
  end

  def self.add_unused_callback(&block)
    (@unused_callbacks ||= []) << block
  end

  def self.unused_callbacks
    @unused_callbacks
  end

  def self.reset_unused_callbacks
    @unused_callbacks = []
  end

  def self.add_in_use_callback(&block)
    (@in_use_callbacks ||= []) << block
  end

  def self.in_use_callbacks
    @in_use_callbacks
  end

  def self.reset_in_use_callbacks
    @in_use_callbacks = []
  end

  def self.with_no_non_post_relations
    self.joins(
      "LEFT JOIN upload_references ur ON ur.upload_id = uploads.id AND ur.target_type != 'Post'",
    ).where("ur.upload_id IS NULL")
  end

  def initialize(*args)
    super
    self.validate_file_size = true
  end

  def to_s
    self.url
  end

  def to_markdown
    UploadMarkdown.new(self).to_markdown
  end

  def thumbnail(width = self.thumbnail_width, height = self.thumbnail_height)
    optimized_images.find_by(width: width, height: height)
  end

  def has_thumbnail?(width, height)
    thumbnail(width, height).present?
  end

  def create_thumbnail!(width, height, opts = nil)
    return unless SiteSetting.create_thumbnails?
    opts ||= {}

    save(validate: false) if get_optimized_image(width, height, opts)
  end

  # this method attempts to correct old incorrect extensions
  def get_optimized_image(width, height, opts = nil)
    opts ||= {}

    fix_image_extension if (!extension || extension.length == 0)

    opts = opts.merge(raise_on_error: true)
    begin
      OptimizedImage.create_for(self, width, height, opts)
    rescue => ex
      Rails.logger.info ex if Rails.env.development?
      opts = opts.merge(raise_on_error: false)
      if fix_image_extension
        OptimizedImage.create_for(self, width, height, opts)
      else
        nil
      end
    end
  end

  def content
    original_path = Discourse.store.path_for(self)
    external_copy = nil

    if original_path.blank?
      external_copy = Discourse.store.download!(self)
      original_path = external_copy.path
    end

    File.read(original_path)
  ensure
    File.unlink(external_copy.path) if external_copy
  end

  def fix_image_extension
    return false if extension == "unknown"

    begin
      # this is relatively cheap once cached
      original_path = Discourse.store.path_for(self)
      if original_path.blank?
        external_copy = Discourse.store.download_safe(self)
        original_path = external_copy&.path
      end

      image_info =
        begin
          FastImage.new(original_path)
        rescue StandardError
          nil
        end
      new_extension = image_info&.type&.to_s || "unknown"

      if new_extension != self.extension
        self.update_columns(extension: new_extension)
        true
      end
    rescue StandardError
      self.update_columns(extension: "unknown")
      true
    end
  end

  def destroy
    Upload.transaction do
      Discourse.store.remove_upload(self)
      super
    end
  end

  def short_url
    "upload://#{short_url_basename}"
  end

  def uploaded_before_secure_uploads_enabled?
    original_sha1.blank?
  end

  def matching_access_control_post?(post)
    access_control_post_id == post.id
  end

  def copied_from_other_post?(post)
    return false if access_control_post_id.blank?
    !matching_access_control_post?(post)
  end

  def short_path
    self.class.short_path(sha1: self.sha1, extension: self.extension)
  end

  def self.consider_for_reuse(upload, post)
    return upload if !SiteSetting.secure_uploads? || upload.blank? || post.blank?
    if !upload.matching_access_control_post?(post) || upload.uploaded_before_secure_uploads_enabled?
      return nil
    end
    upload
  end

  def self.secure_uploads_url?(url)
    # we do not want to exclude topic links that for whatever reason
    # have secure-uploads in the URL e.g. /t/secure-uploads-are-cool/223452
    route = UrlHelper.rails_route_from_url(url)
    return false if route.blank?
    route[:action] == "show_secure" && route[:controller] == "uploads" &&
      FileHelper.is_supported_media?(url)
  rescue ActionController::RoutingError
    false
  end

  def self.signed_url_from_secure_uploads_url(url)
    route = UrlHelper.rails_route_from_url(url)
    url = Rails.application.routes.url_for(route.merge(only_path: true))
    secure_upload_s3_path = url[url.index(route[:path])..-1]
    Discourse.store.signed_url_for_path(secure_upload_s3_path)
  end

  def self.secure_uploads_url_from_upload_url(url)
    return url if !url.include?(SiteSetting.Upload.absolute_base_url)
    uri = URI.parse(url)
    Rails.application.routes.url_for(
      controller: "uploads",
      action: "show_secure",
      path: uri.path[1..-1],
      only_path: true,
    )
  end

  def self.short_path(sha1:, extension:)
    @url_helpers ||= Rails.application.routes.url_helpers

    @url_helpers.upload_short_path(base62: self.base62_sha1(sha1), extension: extension)
  end

  def self.base62_sha1(sha1)
    Base62.encode(sha1.hex)
  end

  def base62_sha1
    Upload.base62_sha1(self.sha1)
  end

  def local?
    !(url =~ %r{\A(https?:)?//})
  end

  def fix_dimensions!
    return if !FileHelper.is_supported_image?("image.#{extension}")

    begin
      path =
        if local?
          Discourse.store.path_for(self)
        else
          Discourse.store.download!(self).path
        end

      if extension == "svg"
        w, h =
          begin
            Discourse::Utils.execute_command(
              "identify",
              "-ping",
              "-format",
              "%w %h",
              path,
              timeout: MAX_IDENTIFY_SECONDS,
            ).split(" ")
          rescue StandardError
            [0, 0]
          end
      else
        w, h = FastImage.new(path, raise_on_failure: true).size
      end

      self.width = w || 0
      self.height = h || 0

      self.thumbnail_width, self.thumbnail_height = ImageSizer.resize(w, h)

      self.update_columns(
        width: width,
        height: height,
        thumbnail_width: thumbnail_width,
        thumbnail_height: thumbnail_height,
      )
    rescue => e
      Discourse.warn_exception(e, message: "Error getting image dimensions")
    end
    nil
  end

  # on demand image size calculation, this allows us to null out image sizes
  # and still handle as needed
  def get_dimension(key)
    if v = read_attribute(key)
      return v
    end
    fix_dimensions!
    read_attribute(key)
  end

  def width
    get_dimension(:width)
  end

  def height
    get_dimension(:height)
  end

  def thumbnail_width
    get_dimension(:thumbnail_width)
  end

  def thumbnail_height
    get_dimension(:thumbnail_height)
  end

  def dominant_color(calculate_if_missing: false)
    val = read_attribute(:dominant_color)
    if val.nil? && calculate_if_missing
      calculate_dominant_color!
      read_attribute(:dominant_color)
    else
      val
    end
  end

  def calculate_dominant_color!(local_path = nil)
    color = nil

    color = "" if !FileHelper.is_supported_image?("image.#{extension}") || extension == "svg"

    if color.nil?
      local_path ||=
        if local?
          Discourse.store.path_for(self)
        else
          Discourse.store.download_safe(self)&.path
        end

      if local_path.nil?
        # Download failed. Could be too large to download, or file could be missing in s3
        color = ""
      end

      color ||=
        begin
          data =
            Discourse::Utils.execute_command(
              "nice",
              "-n",
              "10",
              "convert",
              local_path,
              "-depth",
              "8",
              "-resize",
              "1x1",
              "-define",
              "histogram:unique-colors=true",
              "-format",
              "%c",
              "histogram:info:",
              timeout: DOMINANT_COLOR_COMMAND_TIMEOUT_SECONDS,
            )

          # Output format:
          # 1: (110.873,116.226,93.8821) #6F745E srgb(43.4798%,45.5789%,36.8165%)

          color = data[/#([0-9A-F]{6})/, 1]

          raise "Calculated dominant color but unable to parse output:\n#{data}" if color.nil?

          color
        rescue Discourse::Utils::CommandError => e
          # Timeout or unable to parse image
          # This can happen due to bad user input - ignore and save
          # an empty string to prevent re-evaluation
          ""
        end
    end

    if persisted?
      self.update_column(:dominant_color, color)
    else
      self.dominant_color = color
    end
  end

  def target_image_quality(local_path, test_quality)
    @file_quality ||=
      begin
        Discourse::Utils.execute_command(
          "identify",
          "-ping",
          "-format",
          "%Q",
          local_path,
          timeout: MAX_IDENTIFY_SECONDS,
        ).to_i
      rescue StandardError
        0
      end

    test_quality if @file_quality == 0 || @file_quality > test_quality
  end

  def self.sha1_from_short_path(path)
    self.sha1_from_base62_encoded($2) if path =~ %r{(/uploads/short-url/)([a-zA-Z0-9]+)(\..*)?}
  end

  def self.sha1_from_short_url(url)
    self.sha1_from_base62_encoded($2) if url =~ %r{(upload://)?([a-zA-Z0-9]+)(\..*)?}
  end

  def self.sha1_from_long_url(url)
    $2 if url =~ URL_REGEX || url =~ OptimizedImage::URL_REGEX
  end

  def self.sha1_from_base62_encoded(encoded_sha1)
    sha1 = Base62.decode(encoded_sha1).to_s(16)

    if sha1.length > SHA1_LENGTH
      nil
    else
      sha1.rjust(SHA1_LENGTH, "0")
    end
  end

  def self.generate_digest(path)
    Digest::SHA1.file(path).hexdigest
  end

  def human_filesize
    number_to_human_size(self.filesize)
  end

  def rebake_posts_on_old_scheme
    self.posts.where("cooked LIKE '%/_optimized/%'").find_each(&:rebake!)
  end

  def update_secure_status(source: "unknown", override: nil)
    if override.nil?
      mark_secure, reason = UploadSecurity.new(self).should_be_secure_with_reason
    else
      mark_secure = override
      reason = "manually overridden"
    end

    secure_status_did_change = self.secure? != mark_secure
    self.update(secure_params(mark_secure, reason, source))

    if secure_status_did_change && SiteSetting.s3_use_acls && Discourse.store.external?
      begin
        Discourse.store.update_upload_ACL(self)
      rescue Aws::S3::Errors::NotImplemented => err
        Discourse.warn_exception(
          err,
          message: "The file store object storage provider does not support setting ACLs",
        )
      end
    end

    secure_status_did_change
  end

  def secure_params(secure, reason, source = "unknown")
    {
      secure: secure,
      security_last_changed_reason: reason + " | source: #{source}",
      security_last_changed_at: Time.zone.now,
    }
  end

  def self.migrate_to_new_scheme(limit: nil)
    problems = []

    DistributedMutex.synchronize("migrate_upload_to_new_scheme") do
      if SiteSetting.migrate_to_new_scheme
        max_file_size_kb = [
          SiteSetting.max_image_size_kb,
          SiteSetting.max_attachment_size_kb,
        ].max.kilobytes

        local_store = FileStore::LocalStore.new
        db = RailsMultisite::ConnectionManagement.current_db

        scope =
          Upload
            .by_users
            .where("url NOT LIKE '%/original/_X/%' AND url LIKE ?", "%/uploads/#{db}%")
            .order(id: :desc)

        scope = scope.limit(limit) if limit

        if scope.count == 0
          SiteSetting.migrate_to_new_scheme = false
          return problems
        end

        remap_scope = nil

        scope.each do |upload|
          begin
            # keep track of the url
            previous_url = upload.url.dup
            # where is the file currently stored?
            external = previous_url =~ %r{\A//}
            # download if external
            if external
              url = SiteSetting.scheme + ":" + previous_url

              begin
                retries ||= 0

                file =
                  FileHelper.download(
                    url,
                    max_file_size: max_file_size_kb,
                    tmp_file_name: "discourse",
                    follow_redirect: true,
                  )
              rescue OpenURI::HTTPError
                retry if (retries += 1) < 1
                next
              end

              path = file.path
            else
              path = local_store.path_for(upload)
            end
            # compute SHA if missing
            upload.sha1 = Upload.generate_digest(path) if upload.sha1.blank?

            # store to new location & update the filesize
            File.open(path) do |f|
              upload.url = Discourse.store.store_upload(f, upload)
              upload.filesize = f.size
              upload.save!(validate: false)
            end
            # remap the URLs
            DbHelper.remap(UrlHelper.absolute(previous_url), upload.url) unless external

            DbHelper.remap(
              previous_url,
              upload.url,
              excluded_tables: %w[
                posts
                post_search_data
                incoming_emails
                notifications
                single_sign_on_records
                stylesheet_cache
                topic_search_data
                users
                user_emails
                draft_sequences
                optimized_images
              ],
            )

            remap_scope ||=
              begin
                Post
                  .with_deleted
                  .where(
                    "raw ~ '/uploads/#{db}/\\d+/' OR raw ~ '/uploads/#{db}/original/(\\d|[a-z])/'",
                  )
                  .select(:id, :raw, :cooked)
                  .all
              end

            remap_scope.each do |post|
              post.raw.gsub!(previous_url, upload.url)
              post.cooked.gsub!(previous_url, upload.url)
              if post.changed?
                Post.with_deleted.where(id: post.id).update_all(raw: post.raw, cooked: post.cooked)
              end
            end

            upload.optimized_images.find_each(&:destroy!)
            upload.rebake_posts_on_old_scheme
            # remove the old file (when local)
            FileUtils.rm(path, force: true) unless external
          rescue => e
            problems << { upload: upload, ex: e }
          ensure
            file&.unlink
            file&.close
          end
        end
      end
    end

    problems
  end

  def self.extract_upload_ids(raw)
    return [] if raw.blank?

    sha1s = []

    raw.scan(/\/(\h{40})/).each { |match| sha1s << match[0] }

    raw
      .scan(%r{/([a-zA-Z0-9]+)})
      .each { |match| sha1s << Upload.sha1_from_base62_encoded(match[0]) }

    Upload.where(sha1: sha1s.uniq).pluck(:id)
  end

  def self.backfill_dominant_colors!(count)
    Upload
      .where(dominant_color: nil)
      .order("id desc")
      .first(count)
      .each { |upload| upload.calculate_dominant_color! }
  end

  private

  def short_url_basename
    "#{Upload.base62_sha1(sha1)}#{extension.present? ? ".#{extension}" : ""}"
  end
end

# == Schema Information
#
# Table name: uploads
#
#  id                           :integer          not null, primary key
#  user_id                      :integer          not null
#  original_filename            :string           not null
#  filesize                     :bigint           not null
#  width                        :integer
#  height                       :integer
#  url                          :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  sha1                         :string(40)
#  origin                       :string(1000)
#  retain_hours                 :integer
#  extension                    :string(10)
#  thumbnail_width              :integer
#  thumbnail_height             :integer
#  etag                         :string
#  secure                       :boolean          default(FALSE), not null
#  access_control_post_id       :bigint
#  original_sha1                :string
#  animated                     :boolean
#  verification_status          :integer          default(1), not null
#  security_last_changed_at     :datetime
#  security_last_changed_reason :string
#  dominant_color               :text
#
# Indexes
#
#  idx_uploads_on_verification_status       (verification_status)
#  index_uploads_on_access_control_post_id  (access_control_post_id)
#  index_uploads_on_etag                    (etag)
#  index_uploads_on_extension               (lower((extension)::text))
#  index_uploads_on_id                      (id) WHERE (dominant_color IS NULL)
#  index_uploads_on_id_and_url              (id,url)
#  index_uploads_on_original_sha1           (original_sha1)
#  index_uploads_on_sha1                    (sha1) UNIQUE
#  index_uploads_on_url                     (url)
#  index_uploads_on_user_id                 (user_id)
#
