# frozen_string_literal: true

require "digest/sha1"

class Upload < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include HasUrl

  SHA1_LENGTH = 40
  SEEDED_ID_THRESHOLD = 0
  URL_REGEX ||= /(\/original\/\dX[\/\.\w]*\/([a-zA-Z0-9]+)[\.\w]*)/
  SECURE_MEDIA_ROUTE = "secure-media-uploads".freeze

  belongs_to :user
  belongs_to :access_control_post, class_name: 'Post'

  has_many :post_uploads, dependent: :destroy
  has_many :posts, through: :post_uploads

  has_many :optimized_images, dependent: :destroy
  has_many :user_uploads, dependent: :destroy

  attr_accessor :for_group_message
  attr_accessor :for_theme
  attr_accessor :for_private_message
  attr_accessor :for_export
  attr_accessor :for_site_setting
  attr_accessor :for_gravatar

  validates_presence_of :filesize
  validates_presence_of :original_filename

  validates_with UploadValidator

  after_destroy do
    User.where(uploaded_avatar_id: self.id).update_all(uploaded_avatar_id: nil)
    UserAvatar.where(gravatar_upload_id: self.id).update_all(gravatar_upload_id: nil)
    UserAvatar.where(custom_upload_id: self.id).update_all(custom_upload_id: nil)
  end

  scope :by_users, -> { where("uploads.id > ?", SEEDED_ID_THRESHOLD) }

  def to_s
    self.url
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
    opts[:allow_animation] = SiteSetting.allow_animated_thumbnails

    if get_optimized_image(width, height, opts)
      save(validate: false)
    end
  end

  # this method attempts to correct old incorrect extensions
  def get_optimized_image(width, height, opts)
    if (!extension || extension.length == 0)
      fix_image_extension
    end

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

  def fix_image_extension
    return false if extension == "unknown"

    begin
      # this is relatively cheap once cached
      original_path = Discourse.store.path_for(self)
      if original_path.blank?
        external_copy = Discourse.store.download(self) rescue nil
        original_path = external_copy.try(:path)
      end

      image_info = FastImage.new(original_path) rescue nil
      new_extension = image_info&.type&.to_s || "unknown"

      if new_extension != self.extension
        self.update_columns(extension: new_extension)
        true
      end
    rescue
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

  def short_path
    self.class.short_path(sha1: self.sha1, extension: self.extension)
  end

  def self.consider_for_reuse(upload, post)
    return upload if !SiteSetting.secure_media? || upload.blank? || post.blank?
    return nil if upload.access_control_post_id != post.id || upload.original_sha1.blank?
    upload
  end

  def self.secure_media_url?(url)
    # we do not want to exclude topic links that for whatever reason
    # have secure-media-uploads in the URL e.g. /t/secure-media-uploads-are-cool/223452
    url.include?(SECURE_MEDIA_ROUTE) && !url.include?("/t/") && FileHelper.is_supported_media?(url)
  end

  def self.signed_url_from_secure_media_url(url)
    secure_upload_s3_path = url.sub(Discourse.base_url, "").sub("/#{SECURE_MEDIA_ROUTE}/", "")
    Discourse.store.signed_url_for_path(secure_upload_s3_path)
  end

  def self.secure_media_url_from_upload_url(url)
    url.sub(SiteSetting.Upload.absolute_base_url, "/#{SECURE_MEDIA_ROUTE}")
  end

  def self.short_path(sha1:, extension:)
    @url_helpers ||= Rails.application.routes.url_helpers

    @url_helpers.upload_short_path(
      base62: self.base62_sha1(sha1),
      extension: extension
    )
  end

  def self.base62_sha1(sha1)
    Base62.encode(sha1.hex)
  end

  def base62_sha1
    Upload.base62_sha1(self.sha1)
  end

  def local?
    !(url =~ /^(https?:)?\/\//)
  end

  def fix_dimensions!
    return if !FileHelper.is_supported_image?("image.#{extension}")

    path =
      if local?
        Discourse.store.path_for(self)
      else
        Discourse.store.download(self).path
      end

    begin
      w, h = FastImage.new(path, raise_on_failure: true).size

      self.width = w || 0
      self.height = h || 0

      self.thumbnail_width, self.thumbnail_height = ImageSizer.resize(w, h)

      self.update_columns(
        width: width,
        height: height,
        thumbnail_width: thumbnail_width,
        thumbnail_height: thumbnail_height
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

  def self.sha1_from_short_path(path)
    if path =~ /(\/uploads\/short-url\/)([a-zA-Z0-9]+)(\..*)?/
      self.sha1_from_base62_encoded($2)
    end
  end

  def self.sha1_from_short_url(url)
    if url =~ /(upload:\/\/)?([a-zA-Z0-9]+)(\..*)?/
      self.sha1_from_base62_encoded($2)
    end
  end

  def self.sha1_from_base62_encoded(encoded_sha1)
    sha1 = Base62.decode(encoded_sha1).to_s(16)

    if sha1.length > SHA1_LENGTH
      nil
    else
      sha1.rjust(SHA1_LENGTH, '0')
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

  def update_secure_status(secure_override_value: nil)
    return false if self.for_theme || self.for_site_setting
    mark_secure = secure_override_value.nil? ? UploadSecurity.new(self).should_be_secure? : secure_override_value

    secure_status_did_change = self.secure? != mark_secure
    self.update_column("secure", mark_secure)
    Discourse.store.update_upload_ACL(self) if Discourse.store.external?

    secure_status_did_change
  end

  def self.migrate_to_new_scheme(limit: nil)
    problems = []

    DistributedMutex.synchronize("migrate_upload_to_new_scheme") do
      if SiteSetting.migrate_to_new_scheme
        max_file_size_kb = [
          SiteSetting.max_image_size_kb,
          SiteSetting.max_attachment_size_kb
        ].max.kilobytes

        local_store = FileStore::LocalStore.new
        db = RailsMultisite::ConnectionManagement.current_db

        scope = Upload.by_users
          .where("url NOT LIKE '%/original/_X/%' AND url LIKE '%/uploads/#{db}%'")
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
            external = previous_url =~ /^\/\//
            # download if external
            if external
              url = SiteSetting.scheme + ":" + previous_url

              begin
                retries ||= 0

                file = FileHelper.download(
                  url,
                  max_file_size: max_file_size_kb,
                  tmp_file_name: "discourse",
                  follow_redirect: true
                )
              rescue OpenURI::HTTPError
                retry if (retires += 1) < 1
                next
              end

              path = file.path
            else
              path = local_store.path_for(upload)
            end
            # compute SHA if missing
            if upload.sha1.blank?
              upload.sha1 = Upload.generate_digest(path)
            end

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
              excluded_tables: %w{
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
              }
            )

            remap_scope ||= begin
              Post.with_deleted
                .where("raw ~ '/uploads/#{db}/\\d+/' OR raw ~ '/uploads/#{db}/original/(\\d|[a-z])/'")
                .select(:id, :raw, :cooked)
                .all
            end

            remap_scope.each do |post|
              post.raw.gsub!(previous_url, upload.url)
              post.cooked.gsub!(previous_url, upload.url)
              Post.with_deleted.where(id: post.id).update_all(raw: post.raw, cooked: post.cooked) if post.changed?
            end

            upload.optimized_images.find_each(&:destroy!)
            upload.rebake_posts_on_old_scheme
            # remove the old file (when local)
            unless external
              FileUtils.rm(path, force: true)
            end
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

  def self.reset_unknown_extensions!
    Upload.where(extension: "unknown").update_all(extension: nil)
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
#  id                     :integer          not null, primary key
#  user_id                :integer          not null
#  original_filename      :string           not null
#  filesize               :integer          not null
#  width                  :integer
#  height                 :integer
#  url                    :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  sha1                   :string(40)
#  origin                 :string(1000)
#  retain_hours           :integer
#  extension              :string(10)
#  thumbnail_width        :integer
#  thumbnail_height       :integer
#  etag                   :string
#  secure                 :boolean          default(FALSE), not null
#  access_control_post_id :bigint
#  original_sha1          :string
#
# Indexes
#
#  index_uploads_on_access_control_post_id  (access_control_post_id)
#  index_uploads_on_etag                    (etag)
#  index_uploads_on_extension               (lower((extension)::text))
#  index_uploads_on_id_and_url              (id,url)
#  index_uploads_on_original_sha1           (original_sha1)
#  index_uploads_on_sha1                    (sha1) UNIQUE
#  index_uploads_on_url                     (url)
#  index_uploads_on_user_id                 (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (access_control_post_id => posts.id)
#
