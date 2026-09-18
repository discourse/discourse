# frozen_string_literal: true

class OptimizedImage < ActiveRecord::Base
  include HasUrl
  belongs_to :upload

  # BUMP UP if optimized image algorithm changes
  VERSION = 2
  URL_REGEX = %r{(/optimized/\dX[/\.\w]*/([a-zA-Z0-9]+)[\.\w]*)}
  MAX_PNGQUANT_SIZE = 500_000
  MAX_CONVERT_SECONDS = 20

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
        raise InvalidAccess
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

    upload.fix_image_extension if upload.persisted?
    extension = ".#{opts[:format] || upload.extension}"

    store = Discourse.store

    # create the thumbnail otherwise
    original_path = store.path_for(upload)

    if original_path.blank?
      # download is protected with a DistributedMutex
      original_path = store.download(upload)
    end

    if extension == ".svg" && upload.extension != "svg"
      if opts[:raise_on_error]
        raise InvalidAccess
      else
        # we can not convert any images to svg, unsupported
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

        if GlobalSetting.enable_vips_image_processing
          if %w[.jpg .jpeg].include?(extension.downcase)
            opts = opts.merge(quality: SiteSetting.ImageQuality.image_preview_jpg_quality)
          end
        else
          target_quality =
            upload.target_jpeg_image_quality(
              original_path,
              SiteSetting.ImageQuality.image_preview_jpg_quality,
            )
          opts = opts.merge(quality: target_quality) if target_quality
        end
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

  IM_DECODERS = /\A(jpe?g|png|gif|webp|avif|svg)\z/i

  def self.thumbnail_or_resize
    SiteSetting.strip_image_metadata ? "thumbnail" : "resize"
  end

  def self.resize_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    instructions = ["#{from}[0]"]

    instructions << "-colors" << opts[:colors].to_s if opts[:colors]

    instructions << "-quality" << opts[:quality].to_s if opts[:quality]

    # NOTE: ORDER is important!
    instructions.concat(
      %W[
        -auto-orient
        -gravity
        center
        -background
        transparent
        -#{thumbnail_or_resize}
        #{dimensions}^
        -extent
        #{dimensions}
        -interpolate
        catrom
        -unsharp
        2x0.5+0.7+0
        -interlace
        none
        -profile
        #{Rails.root.join("vendor/data/RT_sRGB.icm")}
        #{to}
      ],
    )
  end

  def self.crop_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    instructions = %W{
      #{from}[0]
      -auto-orient
      -gravity
      north
      -background
      transparent
      -#{thumbnail_or_resize}
      #{dimensions}^
      -crop
      #{dimensions}+0+0
      -unsharp
      2x0.5+0.7+0
      -interlace
      none
      -profile
      #{Rails.root.join("vendor/data/RT_sRGB.icm")}
    }

    instructions << "-quality" << opts[:quality].to_s if opts[:quality]

    instructions << to
  end

  def self.downsize_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    %W{
      #{from}[0]
      -auto-orient
      -gravity
      center
      -background
      transparent
      -interlace
      none
      -resize
      #{dimensions}
      -profile
      #{Rails.root.join("vendor/data/RT_sRGB.icm")}
      #{to}
    }
  end

  def self.resize(from, to, width, height, opts = {})
    if GlobalSetting.enable_vips_image_processing
      ensure_safe_paths!(from, to)
      resize_with_vips(from: from, to: to, width: width, height: height, opts: opts)
    else
      optimize(:optimized_image_resize, from, to, "#{width}x#{height}", opts)
    end
  end

  def self.resize_with_vips(from:, to:, width:, height:, opts:)
    DiscourseVips.thumbnail(
      input_path: from,
      output_path: to,
      width: width,
      height: height,
      size: :both,
      crop: :centre,
      sharpen: true,
      operation: :optimized_image_resize,
      quality: opts[:quality],
      strip_metadata: SiteSetting.strip_image_metadata,
      timeout: MAX_CONVERT_SECONDS,
      read: [from],
      write: [File.dirname(to)],
    )
    optimize_image(to: to)
  rescue => error
    handle_optimization_error(error: error, to: to, opts: opts)
  end
  private_class_method :resize_with_vips

  def self.crop(from, to, width, height, opts = {})
    if GlobalSetting.enable_vips_image_processing
      ensure_safe_paths!(from, to)
      crop_with_vips(from: from, to: to, width: width, height: height, opts: opts)
    else
      optimize(:optimized_image_crop, from, to, "#{width}x#{height}", opts)
    end
  end

  def self.crop_with_vips(from:, to:, width:, height:, opts:)
    DiscourseVips.thumbnail(
      input_path: from,
      output_path: to,
      width: width,
      height: height,
      crop: :all,
      gravity: :north,
      sharpen: true,
      operation: :optimized_image_crop,
      quality: opts[:quality],
      strip_metadata: SiteSetting.strip_image_metadata,
      timeout: MAX_CONVERT_SECONDS,
      read: [from],
      write: [File.dirname(to)],
    )
    optimize_image(to: to)
  rescue => error
    handle_optimization_error(error: error, to: to, opts: opts)
  end
  private_class_method :crop_with_vips

  def self.downsize(from:, to:, scale: nil, width: nil, height: nil, max_pixels: nil, **opts)
    if GlobalSetting.enable_vips_image_processing
      ensure_safe_paths!(from, to)
      downsize_with_vips(
        from: from,
        to: to,
        scale: scale,
        width: width,
        height: height,
        max_pixels: max_pixels,
        opts: opts,
      )
    else
      dimensions =
        if scale
          "#{scale * 100}%"
        elsif max_pixels
          "#{max_pixels}@"
        else
          "#{width}x#{height}>"
        end
      optimize(:optimized_image_downsize, from, to, dimensions, opts)
    end
  end

  def self.downsize_with_vips(from:, to:, scale:, width:, height:, max_pixels:, opts:)
    DiscourseVips.thumbnail(
      input_path: from,
      output_path: to,
      scale: scale,
      width: width,
      height: height,
      max_pixels: max_pixels,
      size: width ? :down : :both,
      sharpen: true,
      operation: :optimized_image_downsize,
      strip_metadata: SiteSetting.strip_image_metadata,
      timeout: MAX_CONVERT_SECONDS,
      read: [from],
      write: [File.dirname(to)],
    )
    optimize_image(to: to)
  rescue => error
    handle_optimization_error(error: error, to: to, opts: opts)
  end
  private_class_method :downsize_with_vips

  INSTRUCTION_METHODS = {
    optimized_image_resize: :resize_instructions,
    optimized_image_crop: :crop_instructions,
    optimized_image_downsize: :downsize_instructions,
  }.freeze
  private_constant :INSTRUCTION_METHODS

  def self.optimize(operation, from, to, dimensions, opts = {})
    instructions = public_send(INSTRUCTION_METHODS.fetch(operation), from, to, dimensions, opts)
    begin
      ImageMagick.magick(
        *instructions,
        operation: operation,
        read: [from],
        write: [File.dirname(to)],
        nice: 10,
        timeout: MAX_CONVERT_SECONDS,
      )
      optimize_image(to: to)
    rescue => error
      handle_optimization_error(error: error, to: to, opts: opts, instructions: instructions)
    end
  end

  def self.optimize_image(to:)
    allow_pngquant = to.downcase.ends_with?(".png") && File.size(to) < MAX_PNGQUANT_SIZE
    FileHelper.optimize_image!(to, allow_pngquant: allow_pngquant)
    true
  end
  private_class_method :optimize_image

  def self.handle_optimization_error(error:, to:, opts:, instructions: nil)
    raise error if opts[:raise_on_error]

    message = +"Failed to optimize image:"
    if error.message =~ /\A(?:convert|magick):([^`]+)/
      message << $1
    elsif error.is_a?(DiscourseVips::Error)
      message << " #{error.message}"
    else
      message << " unknown reason"
    end

    Discourse.warn(
      message,
      upload_id: opts[:upload_id],
      location: to,
      error_message: error.message,
      instructions: instructions,
    )
    false
  end
  private_class_method :handle_optimization_error
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
