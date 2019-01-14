require "digest/sha1"
require_dependency "file_helper"
require_dependency "url_helper"
require_dependency "db_helper"
require_dependency "validators/upload_validator"
require_dependency "file_store/local_store"
require_dependency "base62"

class Upload < ActiveRecord::Base
  SHA1_LENGTH = 40

  belongs_to :user

  has_many :post_uploads, dependent: :destroy
  has_many :posts, through: :post_uploads

  has_many :optimized_images, dependent: :destroy
  has_many :user_uploads, dependent: :destroy

  attr_accessor :for_group_message
  attr_accessor :for_theme
  attr_accessor :for_private_message
  attr_accessor :for_export
  attr_accessor :for_site_setting

  validates_presence_of :filesize
  validates_presence_of :original_filename

  validates_with ::Validators::UploadValidator

  after_destroy do
    User.where(uploaded_avatar_id: self.id).update_all(uploaded_avatar_id: nil)
    UserAvatar.where(gravatar_upload_id: self.id).update_all(gravatar_upload_id: nil)
    UserAvatar.where(custom_upload_id: self.id).update_all(custom_upload_id: nil)
  end

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
    "upload://#{Base62.encode(sha1.hex)}.#{extension}"
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

  def self.sha1_from_short_url(url)
    if url =~ /(upload:\/\/)?([a-zA-Z0-9]+)(\..*)?/
      sha1 = Base62.decode($2).to_s(16)

      if sha1.length > SHA1_LENGTH
        nil
      else
        sha1.rjust(SHA1_LENGTH, '0')
      end
    end
  end

  def self.generate_digest(path)
    Digest::SHA1.file(path).hexdigest
  end

  def self.extract_upload_url(url)
    url.match(/(\/original\/\dX[\/\.\w]*\/([a-zA-Z0-9]+)[\.\w]*)/)
  end

  def self.get_from_url(url)
    return if url.blank?

    uri = begin
      URI(URI.unescape(url))
    rescue URI::Error
    end

    return if uri&.path.blank?
    data = extract_upload_url(uri.path)
    return if data.blank?
    sha1 = data[2]
    upload = nil
    upload = Upload.find_by(sha1: sha1) if sha1&.length == SHA1_LENGTH
    upload || Upload.find_by("url LIKE ?", "%#{data[1]}")
  end

  def self.migrate_to_new_scheme(limit = nil)
    problems = []

    if SiteSetting.migrate_to_new_scheme
      max_file_size_kb = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes
      local_store = FileStore::LocalStore.new

      scope = Upload.where("url NOT LIKE '%/original/_X/%'").order(id: :desc)
      scope = scope.limit(limit) if limit

      scope.each do |upload|
        begin
          # keep track of the url
          previous_url = upload.url.dup
          # where is the file currently stored?
          external = previous_url =~ /^\/\//
          # download if external
          if external
            url = SiteSetting.scheme + ":" + previous_url
            file = FileHelper.download(
              url,
              max_file_size: max_file_size_kb,
              tmp_file_name: "discourse",
              follow_redirect: true
            ) rescue nil
            path = file.path
          else
            path = local_store.path_for(upload)
          end
          # compute SHA if missing
          if upload.sha1.blank?
            upload.sha1 = Upload.generate_digest(path)
          end
          # optimize if image
          FileHelper.optimize_image!(path) if FileHelper.is_supported_image?(File.basename(path))
          # store to new location & update the filesize
          File.open(path) do |f|
            upload.url = Discourse.store.store_upload(f, upload)
            upload.filesize = f.size
            upload.save!
          end
          # remap the URLs
          DbHelper.remap(UrlHelper.absolute(previous_url), upload.url) unless external
          DbHelper.remap(previous_url, upload.url)
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

    problems
  end

end

# == Schema Information
#
# Table name: uploads
#
#  id                :integer          not null, primary key
#  user_id           :integer          not null
#  original_filename :string           not null
#  filesize          :integer          not null
#  width             :integer
#  height            :integer
#  url               :string           not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  sha1              :string(40)
#  origin            :string(1000)
#  retain_hours      :integer
#  extension         :string(10)
#  thumbnail_width   :integer
#  thumbnail_height  :integer
#  etag              :string
#
# Indexes
#
#  index_uploads_on_etag        (etag)
#  index_uploads_on_extension   (lower((extension)::text))
#  index_uploads_on_id_and_url  (id,url)
#  index_uploads_on_sha1        (sha1) UNIQUE
#  index_uploads_on_url         (url)
#  index_uploads_on_user_id     (user_id)
#
