# frozen_string_literal: true

class OptimizedImage < ActiveRecord::Base
  include HasUrl
  belongs_to :upload

  # BUMP UP if optimized image algorithm changes
  VERSION = 2
  VIPS_VERSION = 3
  MAX_VERSION = [VERSION, VIPS_VERSION].max
  URL_REGEX = %r{(/optimized/\dX[/\.\w]*/([a-zA-Z0-9]+)[\.\w]*)}

  def self.version
    SiteSetting.use_vips_for_image_processing ? VIPS_VERSION : VERSION
  end

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

    use_vips = SiteSetting.use_vips_for_image_processing
    processor_version = use_vips ? VIPS_VERSION : VERSION

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
    if thumbnail && (thumbnail.url.blank? || thumbnail.version != processor_version)
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

      if thumbnail && (thumbnail.url.blank? || thumbnail.version != processor_version)
        thumbnail.destroy!
        thumbnail = nil
      end

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
        opts = opts.merge(upload_id: upload.id, use_vips:)

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
              version: processor_version,
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

  IM_DECODERS = /\A(jpe?g|png|ico|gif|webp|avif|svg)\z/i

  def self.prepend_decoder!(path, ext_path = nil, opts = nil)
    "#{image_format!(path:, ext_path:, opts:)}:#{path}"
  end

  def self.image_format!(path:, ext_path: nil, opts: nil)
    opts ||= {}

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

    if !extension || !extension.match?(IM_DECODERS)
      raise Discourse::InvalidAccess.new("Unsupported extension: #{extension}")
    end
    extension.downcase
  end

  def self.thumbnail_or_resize
    SiteSetting.strip_image_metadata ? "thumbnail" : "resize"
  end

  def self.resize_instructions(from, to, dimensions, opts = {})
    ensure_safe_paths!(from, to)

    # note FROM my not be named correctly
    from = prepend_decoder!(from, to, opts)
    to = prepend_decoder!(to, to, opts)

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

    from = prepend_decoder!(from, to, opts)
    to = prepend_decoder!(to, to, opts)

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

    from = prepend_decoder!(from, to, opts)
    to = prepend_decoder!(to, to, opts)

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
    optimize("resize", from, to, "#{width}x#{height}", opts)
  end

  def self.crop(from, to, width, height, opts = {})
    optimize("crop", from, to, "#{width}x#{height}", opts)
  end

  def self.downsize(from, to, dimensions, opts = {})
    optimize("downsize", from, to, dimensions, opts)
  end

  def self.optimize(operation, from, to, dimensions, opts = {})
    instructions = nil
    use_vips = opts.fetch(:use_vips, SiteSetting.use_vips_for_image_processing)

    if use_vips
      source_format = image_format!(path: from, ext_path: to, opts:)
      target_format = image_format!(path: to, ext_path: to, opts:)
      optimize_with_vips(
        operation:,
        from:,
        to:,
        dimensions:,
        source_format:,
        target_format:,
        quality: opts[:quality],
        colors: opts[:colors],
      )
    else
      method_name = "#{operation}_instructions"
      instructions = public_send(method_name.to_sym, from, to, dimensions, opts)
      ImageMagick.magick(
        *instructions,
        read: [from],
        write: [File.dirname(to)],
        nice: 10,
        timeout: MAX_CONVERT_SECONDS,
      )
    end

    allow_pngquant = to.downcase.ends_with?(".png") && File.size(to) < MAX_PNGQUANT_SIZE
    allow_pngquant = false if use_vips && !SiteSetting.strip_image_metadata
    FileHelper.optimize_image!(to, allow_pngquant: allow_pngquant)
    true
  rescue => e
    if opts[:raise_on_error]
      raise e
    else
      error = +"Failed to optimize image:"

      if e.message =~ /\A(?:convert|magick):([^`]+)/
        error << $1
      else
        error << " unknown reason"
      end

      Discourse.warn(
        error,
        upload_id: opts[:upload_id],
        location: to,
        error_message: e.message,
        instructions: instructions,
      )
      false
    end
  end

  def self.optimize_with_vips(
    operation:,
    from:,
    to:,
    dimensions:,
    source_format:,
    target_format:,
    quality:,
    colors:
  )
    ensure_safe_paths!(from, to)

    case operation
    when "resize"
      resize_with_vips(from:, to:, dimensions:, source_format:, target_format:, quality:, colors:)
    when "crop"
      crop_with_vips(from:, to:, dimensions:, source_format:, target_format:, quality:, colors:)
    when "downsize"
      downsize_with_vips(from:, to:, dimensions:, source_format:, target_format:, quality:, colors:)
    else
      raise ArgumentError, "Discourse does not support this image operation: #{operation}"
    end
  end

  def self.resize_with_vips(
    from:,
    to:,
    dimensions:,
    source_format:,
    target_format:,
    quality:,
    colors:
  )
    width, height = parse_vips_box(dimensions)

    Dir.mktmpdir("optimized-image-vips-resize") do |directory|
      resized = File.join(directory, "resized.v")

      Vips.run(
        "vips",
        "thumbnail",
        from,
        resized,
        width.to_s,
        "--height",
        height.to_s,
        "--size",
        "both",
        "--crop",
        "centre",
        "--output-profile",
        VIPS_PROFILE,
        read: [from, VIPS_PROFILE],
        write: [directory],
        timeout: MAX_CONVERT_SECONDS,
        nice: 10,
        allow_untrusted: untrusted_vips_format?(source_format),
      )

      with_vips_output(to:, target_format:) do |output|
        Vips.run(
          "vips",
          "sharpen",
          resized,
          vips_output_argument(output, format: target_format, quality:, colors:),
          "--sigma",
          "0.5",
          "--m1",
          "0.7",
          read: [resized, VIPS_PROFILE],
          write: [File.dirname(output)],
          timeout: MAX_CONVERT_SECONDS,
          nice: 10,
          allow_untrusted: true,
        )
      end
    end
  end

  def self.crop_with_vips(
    from:,
    to:,
    dimensions:,
    source_format:,
    target_format:,
    quality:,
    colors:
  )
    width, height = parse_vips_box(dimensions)
    source_width, source_height = vips_dimensions(from, format: source_format, auto_orient: true)
    scale = [width.fdiv(source_width), height.fdiv(source_height)].max
    cover_width = (source_width * scale).ceil
    cover_height = (source_height * scale).ceil

    Dir.mktmpdir("optimized-image-vips-crop") do |directory|
      intermediate = File.join(directory, "cover.v")

      Vips.run(
        "vips",
        "thumbnail",
        from,
        intermediate,
        cover_width.to_s,
        "--height",
        cover_height.to_s,
        "--size",
        "both",
        "--output-profile",
        VIPS_PROFILE,
        read: [from, VIPS_PROFILE],
        write: [directory],
        timeout: MAX_CONVERT_SECONDS,
        nice: 10,
        allow_untrusted: untrusted_vips_format?(source_format),
      )

      cropped = File.join(directory, "cropped.v")
      Vips.run(
        "vips",
        "gravity",
        intermediate,
        cropped,
        "north",
        width.to_s,
        height.to_s,
        "--extend",
        "background",
        "--background",
        "0 0 0 0",
        read: [intermediate],
        write: [directory],
        timeout: MAX_CONVERT_SECONDS,
        nice: 10,
        allow_untrusted: true,
      )

      with_vips_output(to:, target_format:) do |output|
        Vips.run(
          "vips",
          "sharpen",
          cropped,
          vips_output_argument(output, format: target_format, quality:, colors:),
          "--sigma",
          "0.5",
          "--m1",
          "0.7",
          read: [cropped, VIPS_PROFILE],
          write: [File.dirname(output)],
          timeout: MAX_CONVERT_SECONDS,
          nice: 10,
          allow_untrusted: true,
        )
      end
    end
  end

  def self.downsize_with_vips(
    from:,
    to:,
    dimensions:,
    source_format:,
    target_format:,
    quality:,
    colors:
  )
    width, height, size = vips_downsize_box(path: from, geometry: dimensions, source_format:)

    with_vips_output(to:, target_format:) do |output|
      Vips.run(
        "vips",
        "thumbnail",
        from,
        vips_output_argument(output, format: target_format, quality:, colors:),
        width.to_s,
        "--height",
        height.to_s,
        "--size",
        size,
        "--output-profile",
        VIPS_PROFILE,
        read: [from, VIPS_PROFILE],
        write: [File.dirname(output)],
        timeout: MAX_CONVERT_SECONDS,
        nice: 10,
        allow_untrusted:
          untrusted_vips_format?(source_format) || untrusted_vips_format?(target_format),
      )
    end
  end

  def self.vips_dimensions(path, format:, auto_orient:)
    width, height =
      Vips
        .run(
          "vipsheader",
          "--field",
          "width",
          "--field",
          "height",
          path,
          read: [path],
          timeout: Upload::MAX_IDENTIFY_SECONDS,
          allow_untrusted: untrusted_vips_format?(format),
        )
        .lines(chomp: true)
        .map(&:to_i)

    if auto_orient && vips_rotated?(path, format:)
      [height, width]
    else
      [width, height]
    end
  end

  def self.vips_rotated?(path, format:)
    orientation =
      Vips.run(
        "vipsheader",
        "--field",
        "orientation",
        path,
        read: [path],
        timeout: Upload::MAX_IDENTIFY_SECONDS,
        allow_untrusted: untrusted_vips_format?(format),
      ).to_i
    (5..8).cover?(orientation)
  rescue Discourse::Utils::CommandError
    false
  end

  def self.vips_downsize_box(path:, geometry:, source_format:)
    width, height = vips_dimensions(path, format: source_format, auto_orient: true)

    case geometry
    when /\A(\d+(?:\.\d+)?)%\z/
      scale = Regexp.last_match(1).to_f / 100
      [[(width * scale).round, 1].max, [(height * scale).round, 1].max, "both"]
    when /\A(\d+)@\z/
      scale = Math.sqrt(Regexp.last_match(1).to_f / (width * height))
      [[(width * scale).round, 1].max, [(height * scale).round, 1].max, "both"]
    when /\A(\d+)x(\d+)>?\z/
      [
        Regexp.last_match(1).to_i,
        Regexp.last_match(2).to_i,
        geometry.end_with?(">") ? "down" : "both",
      ]
    else
      raise ArgumentError, "Discourse does not support this image geometry: #{geometry}"
    end
  end

  def self.parse_vips_box(dimensions)
    match = dimensions.match(/\A(\d+)x(\d+)\z/)
    if match.nil?
      raise ArgumentError, "Discourse does not support this image geometry: #{dimensions}"
    end
    [match[1].to_i, match[2].to_i]
  end

  def self.vips_output_argument(path, format:, quality:, colors:)
    format = format.to_s.downcase
    options = [SiteSetting.strip_image_metadata ? "strip=true" : "keep=all"]
    options << "profile=#{VIPS_PROFILE}" if VIPS_PROFILE_FORMATS.include?(format)
    options << "Q=#{quality}" if quality && VIPS_QUALITY_FORMATS.include?(format)
    if colors && format == "png"
      options << "palette=true"
      options << "colours=#{colors}"
    elsif colors && format == "gif"
      options << "bitdepth=#{Math.log2(colors).ceil.clamp(1, 8)}"
    end
    "#{path}[#{options.join(",")}]"
  end

  def self.with_vips_output(to:, target_format:)
    Dir.mktmpdir("optimized-image-vips-output", File.dirname(to)) do |directory|
      output = File.join(directory, "image.#{target_format}")
      yield output
      if !File.file?(output)
        raise Discourse::Utils::CommandError, "vips did not create #{target_format} output"
      end
      File.rename(output, to)
    end
  end

  def self.untrusted_vips_format?(format)
    VIPS_UNTRUSTED_FORMATS.include?(format.to_s.downcase)
  end

  MAX_PNGQUANT_SIZE = 500_000
  MAX_CONVERT_SECONDS = 20
  VIPS_PROFILE = Rails.root.join("vendor/data/RT_sRGB.icm").to_s
  private_constant :VIPS_PROFILE
  VIPS_PROFILE_FORMATS = %w[avif heic heif jpeg jpg jxl png tiff webp].freeze
  private_constant :VIPS_PROFILE_FORMATS
  VIPS_QUALITY_FORMATS = %w[avif heic heif jpeg jpg jxl webp].freeze
  private_constant :VIPS_QUALITY_FORMATS
  VIPS_UNTRUSTED_FORMATS = %w[jxl svg v vips].freeze
  private_constant :VIPS_UNTRUSTED_FORMATS

  private_class_method :image_format!,
                       :optimize_with_vips,
                       :resize_with_vips,
                       :crop_with_vips,
                       :downsize_with_vips,
                       :vips_dimensions,
                       :vips_rotated?,
                       :vips_downsize_box,
                       :parse_vips_box,
                       :vips_output_argument,
                       :with_vips_output,
                       :untrusted_vips_format?
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
