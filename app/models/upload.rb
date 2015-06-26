require "digest/sha1"
require_dependency "image_sizer"
require_dependency "file_helper"
require_dependency "url_helper"
require_dependency "db_helper"
require_dependency "validators/upload_validator"
require_dependency "file_store/local_store"

class Upload < ActiveRecord::Base
  belongs_to :user

  has_many :post_uploads, dependent: :destroy
  has_many :posts, through: :post_uploads

  has_many :optimized_images, dependent: :destroy

  validates_presence_of :filesize
  validates_presence_of :original_filename

  validates_with ::Validators::UploadValidator

  def thumbnail(width = self.width, height = self.height)
    optimized_images.find_by(width: width, height: height)
  end

  def has_thumbnail?(width, height)
    thumbnail(width, height).present?
  end

  def create_thumbnail!(width, height)
    return unless SiteSetting.create_thumbnails?
    thumbnail = OptimizedImage.create_for(self, width, height, allow_animation: SiteSetting.allow_animated_thumbnails)
    if thumbnail
      optimized_images << thumbnail
      self.width = width
      self.height = height
      save(validate: false)
    end
  end

  def destroy
    Upload.transaction do
      Discourse.store.remove_upload(self)
      super
    end
  end

  def extension
    File.extname(original_filename)
  end

  # options
  #   - content_type
  #   - origin
  def self.create_for(user_id, file, filename, filesize, options = {})
    sha1 = Digest::SHA1.file(file).hexdigest

    DistributedMutex.synchronize("upload_#{sha1}") do
      # do we already have that upload?
      upload = find_by(sha1: sha1)

      # make sure the previous upload has not failed
      if upload && upload.url.blank?
        upload.destroy
        upload = nil
      end

      # return the previous upload if any
      return upload unless upload.nil?

      # create the upload otherwise
      upload = Upload.new
      upload.user_id           = user_id
      upload.original_filename = filename
      upload.filesize          = filesize
      upload.sha1              = sha1
      upload.url               = ""
      upload.origin            = options[:origin][0...1000] if options[:origin]

      if FileHelper.is_image?(filename)
        # deal with width & height for images
        upload = resize_image(filename, file, upload)
        # optimize image
        ImageOptim.new.optimize_image!(file.path) rescue nil
      end

      return upload unless upload.save

      # store the file and update its url
      File.open(file.path) do |f|
        url = Discourse.store.store_upload(f, upload, options[:content_type])
        if url.present?
          upload.url = url
          upload.save
        else
          upload.errors.add(:url, I18n.t("upload.store_failure", { upload_id: upload.id, user_id: user_id }))
        end
      end

      # return the uploaded file
      upload
    end
  end

  def self.resize_image(filename, file, upload)
    begin
      if filename =~ /\.svg$/i
        svg = Nokogiri::XML(file).at_css("svg")
        width, height = svg["width"].to_i, svg["height"].to_i
        if width == 0 || height == 0
          upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
        else
          upload.width, upload.height = ImageSizer.resize(width, height)
        end
      else
        # fix orientation first
        Upload.fix_image_orientation(file.path)
        # retrieve image info
        image_info = FastImage.new(file, raise_on_failure: true)
          # compute image aspect ratio
        upload.width, upload.height = ImageSizer.resize(*image_info.size)
      end
      # make sure we're at the beginning of the file
      # (FastImage and Nokogiri move the pointer)
      file.rewind
    rescue FastImage::ImageFetchFailure
      upload.errors.add(:base, I18n.t("upload.images.fetch_failure"))
    rescue FastImage::UnknownImageType
      upload.errors.add(:base, I18n.t("upload.images.unknown_image_type"))
    rescue FastImage::SizeNotFound
      upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
    end

    upload
  end

  def self.get_from_url(url)
    return if url.blank?
    # we store relative urls, so we need to remove any host/cdn
    url = url.sub(/^#{Discourse.asset_host}/i, "") if Discourse.asset_host.present?
    # when using s3, we need to replace with the absolute base url
    url = url.sub(/^#{SiteSetting.s3_cdn_url}/i, Discourse.store.absolute_base_url) if SiteSetting.s3_cdn_url.present?
    Upload.find_by(url: url)
  end

  def self.fix_image_orientation(path)
    `convert #{path} -auto-orient #{path}`
  end

  def self.migrate_to_new_scheme(limit=50)
    problems = []

    if SiteSetting.migrate_to_new_scheme
      max_file_size_kb = [SiteSetting.max_image_size_kb, SiteSetting.max_attachment_size_kb].max.kilobytes
      local_store = FileStore::LocalStore.new

      Upload.where("url NOT LIKE '%/original/_X/%'")
            .limit(limit)
            .order(id: :desc)
            .each do |upload|
        begin
          # keep track of the url
          previous_url = upload.url.dup
          # where is the file currently stored?
          external = previous_url =~ /^\/\//
          # download if external
          if external
            url = SiteSetting.scheme + ":" + previous_url
            file = FileHelper.download(url, max_file_size_kb, "discourse", true) rescue nil
            path = file.path
          else
            path = local_store.path_for(upload)
          end
          # compute SHA if missing
          if upload.sha1.blank?
            upload.sha1 = Digest::SHA1.file(path).hexdigest
          end
          # optimize if image
          if FileHelper.is_image?(File.basename(path))
            ImageOptim.new.optimize_image!(path)
          end
          # store to new location & update the filesize
          File.open(path) do |f|
            upload.url = Discourse.store.store_upload(f, upload)
            upload.filesize = f.size
            upload.save
          end
          # remap the URLs
          DbHelper.remap(UrlHelper.absolute(previous_url), upload.url) unless external
          DbHelper.remap(previous_url, upload.url)
          # remove the old file (when local)
          unless external
            FileUtils.rm(path, force: true) rescue nil
          end
        rescue => e
          problems << { upload: upload, ex: e }
        ensure
          file.try(:unlink) rescue nil
          file.try(:close) rescue nil
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
#  original_filename :string(255)      not null
#  filesize          :integer          not null
#  width             :integer
#  height            :integer
#  url               :string(255)      not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  sha1              :string(40)
#  origin            :string(1000)
#  retain_hours      :integer
#
# Indexes
#
#  index_uploads_on_id_and_url  (id,url)
#  index_uploads_on_sha1        (sha1) UNIQUE
#  index_uploads_on_url         (url)
#  index_uploads_on_user_id     (user_id)
#
