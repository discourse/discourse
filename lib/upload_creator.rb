# frozen_string_literal: true

require "fastimage"

class UploadCreator

  TYPES_TO_CROP ||= %w{avatar card_background custom_emoji profile_background}.each(&:freeze)

  WHITELISTED_SVG_ELEMENTS ||= %w{
    circle clippath defs ellipse feGaussianBlur filter g line linearGradient
    path polygon polyline radialGradient rect stop style svg text textpath
    tref tspan use
  }.each(&:freeze)

  # Available options
  #  - type (string)
  #  - origin (string)
  #  - for_group_message (boolean)
  #  - for_theme (boolean)
  #  - for_private_message (boolean)
  #  - pasted (boolean)
  #  - for_export (boolean)
  #  - for_gravatar (boolean)
  def initialize(file, filename, opts = {})
    @file = file
    @filename = (filename || "").gsub(/[^[:print:]]/, "")
    @upload = Upload.new(original_filename: @filename, filesize: 0)
    @opts = opts
  end

  def create_for(user_id)
    if filesize <= 0
      @upload.errors.add(:base, I18n.t("upload.empty"))
      return @upload
    end

    DistributedMutex.synchronize("upload_#{user_id}_#{@filename}") do
      # test for image regardless of input
      @image_info = FastImage.new(@file) rescue nil

      is_image = FileHelper.is_supported_image?(@filename)
      is_image ||= @image_info && FileHelper.is_supported_image?("test.#{@image_info.type}")
      is_image = false if @opts[:for_theme]

      if is_image
        extract_image_info!
        return @upload if @upload.errors.present?

        if @image_info.type.to_s == "svg"
          whitelist_svg!
        elsif !Rails.env.test? || @opts[:force_optimize]
          convert_to_jpeg! if convert_png_to_jpeg?
          downsize!        if should_downsize?

          return @upload   if is_still_too_big?

          fix_orientation! if should_fix_orientation?
          crop!            if should_crop?
          optimize!        if should_optimize?
        end

        # conversion may have switched the type
        image_type = @image_info.type.to_s
      end

      # compute the sha of the file and generate a unique hash
      # which is only used for secure uploads
      sha1 = Upload.generate_digest(@file)
      unique_hash = SecureRandom.hex(20) if SiteSetting.secure_media

      # we do not check for duplicate uploads if secure media is
      # enabled because we use a unique access hash to differentiate
      # between uploads instead of the sha1, and to get around various
      # access/permission issues for uploads
      if !SiteSetting.secure_media

        # do we already have that upload?
        @upload = Upload.find_by(sha1: sha1)

        # make sure the previous upload has not failed
        if @upload && @upload.url.blank?
          @upload.destroy
          @upload = nil
        end

        # return the previous upload if any
        if @upload
          UserUpload.find_or_create_by!(user_id: user_id, upload_id: @upload.id) if user_id
          return @upload
        end
      end

      fixed_original_filename = nil

      if is_image
        current_extension = File.extname(@filename).downcase.sub("jpeg", "jpg")
        expected_extension = ".#{image_type}".downcase.sub("jpeg", "jpg")

        # we have to correct original filename here, no choice
        # otherwise validation will fail and we can not save
        # TODO decide if we only run the validation on the extension
        if current_extension != expected_extension
          basename = File.basename(@filename, current_extension).presence || "image"
          fixed_original_filename = "#{basename}#{expected_extension}"
        end
      end

      # create the upload otherwise
      @upload = Upload.new
      @upload.user_id           = user_id
      @upload.original_filename = fixed_original_filename || @filename
      @upload.filesize          = filesize
      @upload.sha1              = SiteSetting.secure_media? ? unique_hash : sha1
      @upload.original_sha1     = SiteSetting.secure_media? ? sha1 : nil
      @upload.url               = ""
      @upload.origin            = @opts[:origin][0...1000] if @opts[:origin]
      @upload.extension         = image_type || File.extname(@filename)[1..10]

      if is_image
        @upload.thumbnail_width, @upload.thumbnail_height = ImageSizer.resize(*@image_info.size)
        @upload.width, @upload.height = @image_info.size
      end

      @upload.for_private_message = true if @opts[:for_private_message]
      @upload.for_group_message   = true if @opts[:for_group_message]
      @upload.for_theme           = true if @opts[:for_theme]
      @upload.for_export          = true if @opts[:for_export]
      @upload.for_site_setting    = true if @opts[:for_site_setting]
      @upload.for_gravatar        = true if @opts[:for_gravatar]
      @upload.secure = UploadSecurity.new(@upload, @opts).should_be_secure?

      return @upload unless @upload.save

      # store the file and update its url
      File.open(@file.path) do |f|
        url = Discourse.store.store_upload(f, @upload)

        if url.present?
          @upload.url = url
          @upload.save!
        else
          @upload.errors.add(:url, I18n.t("upload.store_failure", upload_id: @upload.id, user_id: user_id))
        end
      end

      if @upload.errors.empty? && is_image && @opts[:type] == "avatar" && @upload.extension != "svg"
        Jobs.enqueue(:create_avatar_thumbnails, upload_id: @upload.id)
      end

      if @upload.errors.empty?
        UserUpload.find_or_create_by!(user_id: user_id, upload_id: @upload.id) if user_id
      end

      @upload
    end
  ensure
    if @file
      @file.respond_to?(:close!) ? @file.close! : @file.close
    end
  end

  def extract_image_info!
    @image_info = FastImage.new(@file) rescue nil
    @file.rewind

    if @image_info.nil?
      @upload.errors.add(:base, I18n.t("upload.images.not_supported_or_corrupted"))
    elsif filesize <= 0
      @upload.errors.add(:base, I18n.t("upload.empty"))
    elsif pixels == 0
      @upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
    end
  end

  MIN_PIXELS_TO_CONVERT_TO_JPEG ||= 1280 * 720

  def convert_png_to_jpeg?
    return false unless @image_info.type == :png
    return true  if @opts[:pasted]
    return false if SiteSetting.png_to_jpg_quality == 100
    pixels > MIN_PIXELS_TO_CONVERT_TO_JPEG
  end

  MIN_CONVERT_TO_JPEG_BYTES_SAVED = 75_000
  MIN_CONVERT_TO_JPEG_SAVING_RATIO = 0.70

  def convert_to_jpeg!
    return if filesize < MIN_CONVERT_TO_JPEG_BYTES_SAVED

    jpeg_tempfile = Tempfile.new(["image", ".jpg"])

    from = @file.path
    to = jpeg_tempfile.path

    OptimizedImage.ensure_safe_paths!(from, to)

    from = OptimizedImage.prepend_decoder!(from, nil, filename: "image.#{@image_info.type}")
    to = OptimizedImage.prepend_decoder!(to)

    begin
      execute_convert(from, to)
    rescue
      # retry with debugging enabled
      execute_convert(from, to, true)
    end

    new_size = File.size(jpeg_tempfile.path)

    keep_jpeg = new_size < filesize * MIN_CONVERT_TO_JPEG_SAVING_RATIO
    keep_jpeg &&= (filesize - new_size) > MIN_CONVERT_TO_JPEG_BYTES_SAVED

    if keep_jpeg
      @file.respond_to?(:close!) ? @file.close! : @file.close
      @file = jpeg_tempfile
      extract_image_info!
    else
      jpeg_tempfile.close!
    end
  end

  def execute_convert(from, to, debug = false)
    command = [
      "convert",
      from,
      "-auto-orient",
      "-background", "white",
      "-interlace", "none",
      "-flatten",
      "-quality", SiteSetting.png_to_jpg_quality.to_s
    ]
    command << "-debug" << "all" if debug
    command << to

    Discourse::Utils.execute_command(*command, failure_message: I18n.t("upload.png_to_jpg_conversion_failure_message"))
  end

  def should_downsize?
    max_image_size > 0 && filesize >= max_image_size
  end

  def downsize!
    3.times do
      original_size = filesize
      down_tempfile = Tempfile.new(["down", ".#{@image_info.type}"])

      from = @file.path
      to = down_tempfile.path

      OptimizedImage.ensure_safe_paths!(from, to)

      OptimizedImage.downsize(
        from,
        to,
        "50%",
        filename: @filename,
        allow_animation: allow_animation,
        raise_on_error: true
      )

      @file.respond_to?(:close!) ? @file.close! : @file.close
      @file = down_tempfile

      extract_image_info!

      return if filesize >= original_size || pixels == 0 || !should_downsize?
    end
  end

  def is_still_too_big?
    if max_image_pixels > 0 && pixels >= max_image_pixels
      @upload.errors.add(:base, I18n.t("upload.images.larger_than_x_megapixels", max_image_megapixels: SiteSetting.max_image_megapixels))
      true
    elsif max_image_size > 0 && filesize >= max_image_size
      @upload.errors.add(:base, I18n.t("upload.images.too_large", max_size_kb: SiteSetting.max_image_size_kb))
      true
    else
      false
    end
  end

  def whitelist_svg!
    doc = Nokogiri::XML(@file)
    doc.xpath(svg_whitelist_xpath).remove
    doc.xpath("//@*[starts-with(name(), 'on')]").remove
    File.write(@file.path, doc.to_s)
    @file.rewind
  end

  def should_fix_orientation?
    # orientation is between 1 and 8, 1 being the default
    # cf. http://www.daveperrett.com/articles/2012/07/28/exif-orientation-handling-is-a-ghetto/
    @image_info.orientation.to_i > 1
  end

  def fix_orientation!
    path = @file.path

    OptimizedImage.ensure_safe_paths!(path)
    path = OptimizedImage.prepend_decoder!(path, nil, filename: "image.#{@image_info.type}")

    Discourse::Utils.execute_command('convert', path, '-auto-orient', path)

    extract_image_info!
  end

  def should_crop?
    TYPES_TO_CROP.include?(@opts[:type])
  end

  def crop!
    max_pixel_ratio = Discourse::PIXEL_RATIOS.max
    filename_with_correct_ext = "image.#{@image_info.type}"

    case @opts[:type]
    when "avatar"
      width = height = Discourse.avatar_sizes.max
      OptimizedImage.resize(@file.path, @file.path, width, height, filename: filename_with_correct_ext, allow_animation: allow_animation)
    when "profile_background"
      max_width = 850 * max_pixel_ratio
      width, height = ImageSizer.resize(@image_info.size[0], @image_info.size[1], max_width: max_width, max_height: max_width)
      OptimizedImage.downsize(@file.path, @file.path, "#{width}x#{height}\>", filename: filename_with_correct_ext, allow_animation: allow_animation)
    when "card_background"
      max_width = 590 * max_pixel_ratio
      width, height = ImageSizer.resize(@image_info.size[0], @image_info.size[1], max_width: max_width, max_height: max_width)
      OptimizedImage.downsize(@file.path, @file.path, "#{width}x#{height}\>", filename: filename_with_correct_ext, allow_animation: allow_animation)
    when "custom_emoji"
      OptimizedImage.downsize(@file.path, @file.path, "100x100\>", filename: filename_with_correct_ext, allow_animation: allow_animation)
    end

    extract_image_info!
  end

  def should_optimize?
    # GIF is too slow (plus, we'll soon be converting them to MP4)
    # Optimizing SVG is useless
    return false if @file.path =~ /\.(gif|svg)$/i
    # Safeguard for large PNGs
    return pixels < 2_000_000 if @file.path =~ /\.png/i
    # Everything else is fine!
    true
  end

  def optimize!
    OptimizedImage.ensure_safe_paths!(@file.path)
    FileHelper.optimize_image!(@file.path)
    extract_image_info!
  rescue ImageOptim::TimeoutExceeded
    Rails.logger.warn("ImageOptim timed out while optimizing #{@filename}")
  end

  def filesize
    File.size?(@file.path).to_i
  end

  def max_image_size
    @max_image_size ||= SiteSetting.max_image_size_kb.kilobytes
  end

  def max_image_pixels
    @max_image_pixels ||= SiteSetting.max_image_megapixels * 1_000_000
  end

  def pixels
    @image_info.size&.reduce(:*).to_i
  end

  def allow_animation
    @allow_animation ||= @opts[:type] == "avatar" ? SiteSetting.allow_animated_avatars : SiteSetting.allow_animated_thumbnails
  end

  def svg_whitelist_xpath
    @@svg_whitelist_xpath ||= "//*[#{WHITELISTED_SVG_ELEMENTS.map { |e| "name()!='#{e}'" }.join(" and ") }]"
  end

end
