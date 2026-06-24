# frozen_string_literal: true

class OptimizedImage < ActiveRecord::Base
  include HasUrl
  belongs_to :upload

  # BUMP UP if optimized image algorithm changes
  VERSION = 2
  URL_REGEX = %r{(/optimized/\dX[/\.\w]*/([a-zA-Z0-9]+)[\.\w]*)}

  def self.lock(upload_id, width, height)
    @hostname ||= Discourse.os_hostname
    # note, the extra lock here ensures we only optimize one image per machine on webs
    # this can very easily lead to runaway CPU so slowing it down is beneficial and it is hijacked
    #
    # we can not afford this blocking in Sidekiq cause it can lead to starvation
    if lock_per_machine?
      DistributedMutex.synchronize("optimized_image_host_#{@hostname}") do
        DistributedMutex.synchronize("optimized_image_#{upload_id}_#{width}_#{height}") { yield }
      end
    else
      DistributedMutex.synchronize("optimized_image_#{upload_id}_#{width}_#{height}") { yield }
    end
  end

  def self.lock_per_machine?
    return @lock_per_machine if defined?(@lock_per_machine)
    @lock_per_machine = !Sidekiq.server?
  end

  def self.lock_per_machine=(value)
    @lock_per_machine = value
  end

  def self.create_for(upload, width, height, opts = {})
    return if width <= 0 || height <= 0
    return if upload.try(:sha1).blank?

    # no extension so try to guess it
    upload.fix_image_extension if !upload.extension

    if !upload.extension.match?(IM_DECODERS)
      if opts[:raise_on_error]
        raise Discourse::InvalidAccess
      else
        # nothing to do ... bad extension, not an image
        return
      end
    end

    # prefer to look up the thumbnail without grabbing any locks
    extension = ".#{opts[:format] || upload.extension}"
    thumbnail = find_by(upload_id: upload.id, width: width, height: height, extension: extension)

    # correct bad thumbnail if needed
    if thumbnail && (thumbnail.url.blank? || thumbnail.version != VERSION)
      thumbnail.destroy!
      thumbnail = nil
    end

    return thumbnail if thumbnail

    store = Discourse.store

    # create the thumbnail otherwise
    original_path = store.path_for(upload)

    if original_path.blank?
      # download is protected with a DistributedMutex
      original_path = store.download(upload)
    end

    if extension == ".svg" && upload.extension != "svg"
      if opts[:raise_on_error]
        raise Discourse::InvalidAccess
      else
        # we can not convert any images to svg, unsupported
        return
      end
    elsif upload.extension == "svg" && extension != ".svg"
      if opts[:raise_on_error]
        raise Discourse::InvalidAccess
      else
        # SVG rasterization is intentionally outside the Safe Image migration.
        return
      end
    end

    lock(upload.id, width, height) do
      # may have been generated since we got the lock
      thumbnail = find_by(upload_id: upload.id, width: width, height: height, extension: extension)

      # return the previous thumbnail if any
      return thumbnail if thumbnail

      if original_path.blank?
        Rails.logger.error("Could not find file in the store located at url: #{upload.url}")
      else
        # create a temp file with the same extension as the original

        return nil if extension.length == 1

        temp_file = Tempfile.new(["discourse-thumbnail", extension])
        temp_path = temp_file.path

        target_quality =
          upload.target_image_quality(
            original_path,
            SiteSetting.ImageQuality.image_preview_jpg_quality,
          )
        opts = opts.merge(quality: target_quality) if target_quality
        opts = opts.merge(upload_id: upload.id)

        # special case, when "resizing" vectors we simply copy
        if extension == ".svg"
          FileUtils.cp(original_path, temp_path)
          resized = true
        elsif opts[:crop]
          resized = crop(original_path, temp_path, width, height, opts)
        else
          resized = resize(original_path, temp_path, width, height, opts)
        end

        if resized
          # TODO: crop vs resize should be stored in the db, quality should be stored
          thumbnail =
            OptimizedImage.create!(
              upload_id: upload.id,
              sha1: Upload.generate_digest(temp_path),
              extension: extension,
              width: width,
              height: height,
              url: "",
              filesize: File.size(temp_path),
              version: VERSION,
            )

          # store the optimized image and update its url
          File.open(temp_path) do |file|
            url = store.store_optimized_image(file, thumbnail, nil, secure: upload.secure?)
            if url.present?
              thumbnail.url = url
              thumbnail.save
            else
              Rails.logger.error(
                "Failed to store optimized image of size #{width}x#{height} from url: #{upload.url}\nTemp image path: #{temp_path}",
              )
            end
          end
        end

        # close && remove temp file
        temp_file.close!
      end

      thumbnail
    end
  end

  def destroy
    OptimizedImage.transaction do
      Discourse.store.remove_optimized_image(self) if upload
      super
    end
  end

  def local?
    !(url =~ %r{\A(https?:)?//})
  end

  def calculate_filesize
    path =
      if local?
        Discourse.store.path_for(self)
      else
        Discourse.store.download!(self)
      end
    File.size(path)
  end

  def filesize
    if size = read_attribute(:filesize)
      size
    else
      size = calculate_filesize

      self[:filesize] = size
      update_columns(filesize: size) if !new_record?
      size
    end
  end

  def self.safe_path?(path)
    # this matches instructions which call #to_s
    path = path.to_s
    return false if path != File.expand_path(path)
    return false if path !~ %r{\A[\w\-\./]+\z}m
    true
  end

  def self.ensure_safe_paths!(*paths)
    paths.each { |path| raise Discourse::InvalidAccess unless safe_path?(path) }
  end

  IM_DECODERS = /\A(jpe?g|png|ico|gif|webp|avif|heic|heif|jxl|svg)\z/i

  def self.supported_extension!(path, ext_path = nil, opts = nil)
    opts ||= {}

    extension =
      if opts[:format]
        opts[:format].to_s
      elsif path != ext_path
        File.extname(path)[1..-1]
      else
        File.extname(opts[:filename] || ext_path || path)[1..-1]
      end

    extension = extension.to_s.delete_prefix(".").downcase if extension
    extension = "jpg" if extension == "jpeg"

    if !extension || !extension.match?(IM_DECODERS)
      raise Discourse::InvalidAccess.new("Unsupported extension: #{extension}")
    end

    extension
  end

  def self.prepend_decoder!(path, ext_path = nil, opts = nil)
    supported_extension!(path, ext_path, opts)
    path
  end

  MAX_PNGQUANT_SIZE = 500_000

  def self.resize(from, to, width, height, opts = {})
    process(:resize, from, to, [width, height], opts)
  end

  def self.crop(from, to, width, height, opts = {})
    process(:crop, from, to, [width, height], opts)
  end

  def self.downsize(from, to, dimensions, opts = {})
    process(:downsize, from, to, [dimensions], opts)
  end

  def self.process(operation, from, to, args, opts = {})
    ensure_safe_paths!(from, to)
    supported_extension!(to, to, opts)

    safe_image_options = {
      filename: opts[:filename],
      output_extension: opts[:format] || File.extname(opts[:filename].to_s).delete_prefix("."),
      quality: opts[:quality],
      optimize: false,
    }.compact

    DiscourseImage.public_send(operation, from, to, *args, **safe_image_options)

    allow_pngquant = to.downcase.ends_with?(".png") && File.size(to) < MAX_PNGQUANT_SIZE
    FileHelper.optimize_image!(to, allow_pngquant: allow_pngquant)
    true
  rescue => e
    if opts[:raise_on_error]
      raise e
    else
      Discourse.warn(
        "Failed to optimize image",
        upload_id: opts[:upload_id],
        location: to,
        error_class: e.class.name,
        error_message: e.message,
        operation: operation,
      )
      false
    end
  end
end

# == Schema Information
#
# Table name: optimized_images
#
#  id         :integer          not null, primary key
#  etag       :string
#  extension  :string(10)       not null
#  filesize   :integer
#  height     :integer          not null
#  sha1       :string(40)       not null
#  url        :string           not null
#  version    :integer
#  width      :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  upload_id  :integer          not null
#
# Indexes
#
#  index_optimized_images_on_etag       (etag)
#  index_optimized_images_on_upload_id  (upload_id)
#  index_optimized_images_unique        (upload_id,width,height,extension) UNIQUE
#
