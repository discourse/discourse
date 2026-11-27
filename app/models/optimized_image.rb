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

    if !upload.extension.match?(SUPPORTED_EXTENSIONS)
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

    store = Discourse.store

    original_path = store.download(upload)

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

        if %w[.jpg .jpeg].include?(extension.downcase)
          opts = opts.merge(quality: SiteSetting.ImageQuality.image_preview_jpg_quality)
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
    File.size(Discourse.store.download!(self))
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

  SUPPORTED_EXTENSIONS = /\A(jpe?g|png|gif|webp|avif|svg)\z/i

  def self.image_extension(path:, ext_path:, opts:)
    # This logic is a little messy but the result of using mocks for most
    # of the image tests. The idea here is you shouldn't trust the "original"
    # path of a file to figure out its extension. However, in certain cases
    # such as generating the loading upload thumbnail, we force the format,
    # and this allows us to use the forced format in that case.
    extension = nil
    if opts[:format] && path != ext_path
      extension = File.extname(path)[1..-1]
    else
      extension = File.extname(opts[:filename] || ext_path || path)[1..-1]
    end

    if !extension || !extension.match?(SUPPORTED_EXTENSIONS)
      raise Discourse::InvalidAccess.new("Unsupported extension: #{extension}")
    end
    extension
  end
  private_class_method :image_extension

  def self.resize(from, to, width, height, opts = {})
    quality = opts[:quality]
    if quality.nil? && image_extension(path: to, ext_path: to, opts: opts).match?(/\Ajpe?g\z/i)
      quality = SiteSetting.ImageQuality.image_preview_jpg_quality
    end

    thumbnail(
      from,
      to,
      opts,
      width:,
      height:,
      size: :both,
      crop: :centre,
      quality:,
      operation: :optimized_image_resize,
    )
  end

  def self.crop(from, to, width, height, opts = {})
    thumbnail(
      from,
      to,
      opts,
      width:,
      height:,
      crop: :all,
      gravity: :north,
      quality: opts[:quality],
      operation: :optimized_image_crop,
    )
  end

  def self.downsize(from:, to:, scale: nil, width: nil, height: nil, max_pixels: nil, **opts)
    thumbnail(
      from,
      to,
      opts,
      scale:,
      width:,
      height:,
      max_pixels:,
      size: width ? :down : :both,
      operation: :optimized_image_downsize,
    )
  end

  def self.thumbnail(from, to, opts, **options)
    ensure_safe_paths!(from, to)
    begin
      DiscourseVips.thumbnail(
        input_path: from,
        output_path: to,
        input_format: image_extension(path: from, ext_path: to, opts: opts),
        output_format: image_extension(path: to, ext_path: to, opts: opts),
        sharpen: true,
        strip_metadata: SiteSetting.strip_image_metadata,
        timeout: MAX_CONVERT_SECONDS,
        **options,
      )
      optimize_image(to: to)
    rescue => error
      handle_optimization_error(error: error, to: to, opts: opts)
    end
  end
  private_class_method :thumbnail

  def self.optimize_image(to:)
    allow_pngquant = to.downcase.ends_with?(".png") && File.size(to) < MAX_PNGQUANT_SIZE
    FileHelper.optimize_image!(to, allow_pngquant: allow_pngquant)
    true
  end
  private_class_method :optimize_image

  def self.handle_optimization_error(error:, to:, opts:)
    raise error if opts[:raise_on_error]

    message = +"Failed to optimize image:"
    if error.is_a?(DiscourseVips::Error)
      message << " #{error.message}"
    else
      message << " unknown reason"
    end

    Discourse.warn(message, upload_id: opts[:upload_id], location: to, error_message: error.message)
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
