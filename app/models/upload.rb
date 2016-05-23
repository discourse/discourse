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

  attr_accessor :is_attachment_for_group_message

  validates_presence_of :filesize
  validates_presence_of :original_filename

  validates_with ::Validators::UploadValidator

  def thumbnail(width = self.width, height = self.height)
    optimized_images.find_by(width: width, height: height)
  end

  def has_thumbnail?(width, height)
    thumbnail(width, height).present?
  end

  def create_thumbnail!(width, height, crop=false)
    return unless SiteSetting.create_thumbnails?

    opts = {
      filename: self.original_filename,
      allow_animation: SiteSetting.allow_animated_thumbnails,
      crop: crop
    }

    if thumbnail = OptimizedImage.create_for(self, width, height, opts)
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

  # list of image types that will be cropped
  CROPPED_IMAGE_TYPES ||= %w{avatar profile_background card_background}

  # options
  #   - content_type
  #   - origin (url)
  #   - image_type ("avatar", "profile_background", "card_background")
  #   - is_attachment_for_group_message (boolean)
  def self.create_for(user_id, file, filename, filesize, options = {})
    DistributedMutex.synchronize("upload_#{user_id}_#{filename}") do
      # do some work on images
      if FileHelper.is_image?(filename) && is_actual_image?(file)
        if filename =~ /\.svg$/i
          svg = Nokogiri::XML(file).at_css("svg")
          w = svg["width"].to_i
          h = svg["height"].to_i
        else
          # fix orientation first
          fix_image_orientation(file.path) if should_optimize?(file.path)
          # retrieve image info
          image_info = FastImage.new(file) rescue nil
          w, h = *(image_info.try(:size) || [0, 0])
        end

        # default size
        width, height = ImageSizer.resize(w, h)

        # make sure we're at the beginning of the file (both FastImage and Nokogiri move the pointer)
        file.rewind

        # crop images depending on their type
        if CROPPED_IMAGE_TYPES.include?(options[:image_type])
          allow_animation = SiteSetting.allow_animated_thumbnails
          max_pixel_ratio = Discourse::PIXEL_RATIOS.max

          case options[:image_type]
          when "avatar"
            allow_animation = SiteSetting.allow_animated_avatars
            width = height = Discourse.avatar_sizes.max
            OptimizedImage.resize(file.path, file.path, width, height, filename: filename, allow_animation: allow_animation)
          when "profile_background"
            max_width = 850 * max_pixel_ratio
            width, height = ImageSizer.resize(w, h, max_width: max_width, max_height: max_width)
            OptimizedImage.downsize(file.path, file.path, "#{width}x#{height}", filename: filename, allow_animation: allow_animation)
          when "card_background"
            max_width = 590 * max_pixel_ratio
            width, height = ImageSizer.resize(w, h, max_width: max_width, max_height: max_width)
            OptimizedImage.downsize(file.path, file.path, "#{width}x#{height}", filename: filename, allow_animation: allow_animation)
          end
        end

        # optimize image (except GIFs and large PNGs)
        if should_optimize?(file.path)
          ImageOptim.new.optimize_image!(file.path) rescue nil
          # update the file size
          filesize = File.size(file.path)
        end
      end

      # compute the sha of the file
      sha1 = Digest::SHA1.file(file).hexdigest

      # do we already have that upload?
      upload = find_by(sha1: sha1)

      # make sure the previous upload has not failed
      if upload && (upload.url.blank? || is_dimensionless_image?(filename, upload.width, upload.height))
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
      upload.width             = width
      upload.height            = height
      upload.origin            = options[:origin][0...1000] if options[:origin]

      if options[:is_attachment_for_group_message]
        upload.is_attachment_for_group_message = true
      end

      if is_dimensionless_image?(filename, upload.width, upload.height)
        upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
        return upload
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

      upload
    end
  end

  def self.is_actual_image?(file)
    # due to ImageMagick CVE-2016–3714, use FastImage to check the magic bytes
    # cf. https://meta.discourse.org/t/imagemagick-cve-2016-3714/43624
    FastImage.size(file, raise_on_failure: true)
  rescue
    false
  end

  LARGE_PNG_SIZE ||= 3.megabytes

  def self.should_optimize?(path)
    # don't optimize GIFs
    return false if path =~ /\.gif$/i
    return true  if path !~ /\.png$/i
    image_info = FastImage.new(path) rescue nil
    w, h = *(image_info.try(:size) || [0, 0])
    # don't optimize large PNGs
    w > 0 && h > 0 && w * h < LARGE_PNG_SIZE
  end

  def self.is_dimensionless_image?(filename, width, height)
    FileHelper.is_image?(filename) && (width.blank? || width == 0 || height.blank? || height == 0)
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
#
# Indexes
#
#  index_uploads_on_id_and_url  (id,url)
#  index_uploads_on_sha1        (sha1) UNIQUE
#  index_uploads_on_url         (url)
#  index_uploads_on_user_id     (user_id)
#
