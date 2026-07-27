# frozen_string_literal: true

class OptimizedImage < ActiveRecord::Base
  include HasUrl
  belongs_to :upload

  # BUMP UP if optimized image algorithm changes
  VERSION = 3
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

    if !%w[jpg jpeg png ico gif webp avif svg].include?(upload.extension.downcase)
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

        opts = opts.merge(quality: SiteSetting.ImageQuality.image_preview_jpg_quality)
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

  def self.resize(from, to, width, height, opts = {})
    process(from: from, to: to, opts: opts) do |output_path|
      DiscourseImage.crop(
        input: from,
        output: output_path,
        width: width,
        height: height,
        position: :center,
        maximum_quality: opts[:quality],
      )
    end
  end

  def self.crop(from, to, width, height, opts = {})
    process(from: from, to: to, opts: opts) do |output_path|
      DiscourseImage.crop(
        input: from,
        output: output_path,
        width: width,
        height: height,
        position: :top,
        maximum_quality: opts[:quality],
      )
    end
  end

  def self.downsize(from, to, dimensions, opts = {})
    process(from: from, to: to, opts: opts) do |output_path|
      resize_options = parse_resize_options(from: from, dimensions: dimensions)
      DiscourseImage.resize(input: from, output: output_path, **resize_options)
    end
  end

  def self.process(from:, to:, opts:)
    extension = output_extension(from: from, to: to, opts: opts)
    return yield(to) if File.extname(to).delete_prefix(".").casecmp?(extension)

    Tempfile.create(["optimized-image", ".#{extension}"], File.dirname(to), binmode: true) do |file|
      temporary_path = file.path
      file.close
      FileUtils.rm_f(temporary_path)
      result = yield(temporary_path)
      FileUtils.mv(temporary_path, to) if result
      result
    ensure
      FileUtils.rm_f(temporary_path) if temporary_path
    end
  rescue => error
    raise if opts[:raise_on_error]

    Discourse.warn(
      "Failed to optimize image: #{error.message}",
      upload_id: opts[:upload_id],
      location: to,
      error_message: error.message,
    )
    false
  end
  private_class_method :process

  def self.output_extension(from:, to:, opts:)
    extension = File.extname(to).delete_prefix(".")
    return extension if FileHelper.supported_images.include?(extension.downcase)

    hint = opts[:format] || File.extname(opts[:filename].to_s).delete_prefix(".")
    (hint.presence || DiscourseImage.type(from)).to_s.sub(/\Ajpeg\z/, "jpg")
  end
  private_class_method :output_extension

  def self.parse_resize_options(from:, dimensions:)
    case dimensions
    when /\A(\d+(?:\.\d+)?)%\z/
      { scale: $1.to_f / 100, allow_upscale: true }
    when /\A(\d+)@\z/
      width, height = DiscourseImage.size(from)
      { scale: Math.sqrt($1.to_f / (width * height)), allow_upscale: true }
    when /\A(\d*)x(\d*)>\z/
      width = $1.presence&.to_i
      height = $2.presence&.to_i
      raise ArgumentError, "invalid resize dimensions" if width.nil? && height.nil?

      { width: width, height: height, allow_upscale: false }
    else
      raise ArgumentError, "invalid resize dimensions"
    end
  end
  private_class_method :parse_resize_options
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
