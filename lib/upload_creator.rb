# frozen_string_literal: true

require "fastimage"

class UploadCreator

  TYPES_TO_CROP ||= %w{avatar card_background custom_emoji profile_background}.each(&:freeze)

  ALLOWED_SVG_ELEMENTS ||= %w{
    circle clipPath defs ellipse feGaussianBlur filter g line linearGradient
    marker path polygon polyline radialGradient rect stop style svg text
    textPath tref tspan use
  }.each(&:freeze)

  include ActiveSupport::Deprecation::DeprecatedConstantAccessor
  deprecate_constant 'WHITELISTED_SVG_ELEMENTS', 'UploadCreator::ALLOWED_SVG_ELEMENTS'

  # Available options
  #  - type (string)
  #  - origin (string)
  #  - for_group_message (boolean)
  #  - for_theme (boolean)
  #  - for_private_message (boolean)
  #  - pasted (boolean)
  #  - for_export (boolean)
  #  - for_gravatar (boolean)
  #  - skip_validations (boolean)
  def initialize(file, filename, opts = {})
    @file = file
    @filename = (filename || "").gsub(/[^[:print:]]/, "")
    @upload = Upload.new(original_filename: @filename, filesize: 0)
    @opts = opts
    @opts[:validate] = opts[:skip_validations].present? ? !ActiveRecord::Type::Boolean.new.cast(opts[:skip_validations]) : true
  end

  def create_for(user_id)
    if filesize <= 0
      @upload.errors.add(:base, I18n.t("upload.empty"))
      return @upload
    end

    @image_info = FastImage.new(@file) rescue nil
    is_image = FileHelper.is_supported_image?(@filename)
    is_image ||= @image_info && FileHelper.is_supported_image?("test.#{@image_info.type}")
    is_image = false if @opts[:for_theme]

    DistributedMutex.synchronize("upload_#{user_id}_#{@filename}") do
      # We need to convert HEIFs early because FastImage does not consider them as images
      if convert_heif_to_jpeg?
        convert_heif!
        is_image = FileHelper.is_supported_image?("test.#{@image_info.type}")
      end

      if is_image
        extract_image_info!
        return @upload if @upload.errors.present?

        if @image_info.type.to_s == "svg"
          clean_svg!
        elsif !Rails.env.test? || @opts[:force_optimize]
          convert_to_jpeg! if convert_png_to_jpeg? || should_alter_quality?
          fix_orientation! if should_fix_orientation?
          crop!            if should_crop?
          optimize!        if should_optimize?
          downsize!        if should_downsize?
          return @upload   if is_still_too_big?
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
          add_metadata!
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
        if @image_info.type.to_s == 'svg'
          w, h = [0, 0]

          begin
            w, h = Discourse::Utils
              .execute_command("identify", "-ping", "-format", "%w %h", @file.path, timeout: Upload::MAX_IDENTIFY_SECONDS)
              .split(' ')
          rescue
            # use default 0, 0
          end
        else
          w, h = @image_info.size
        end

        @upload.thumbnail_width, @upload.thumbnail_height = ImageSizer.resize(w, h)
        @upload.width, @upload.height = w, h
        @upload.animated = animated?
      end

      add_metadata!

      if SiteSetting.secure_media
        secure, reason = UploadSecurity.new(@upload, @opts.merge(creating: true)).should_be_secure_with_reason
        attrs = @upload.secure_params(secure, reason, "upload creator")
        @upload.assign_attributes(attrs)
      end

      # Callbacks using this event to validate the upload or the file must add errors to the
      # upload errors object.
      DiscourseEvent.trigger(:before_upload_creation, @file, is_image, @upload, @opts[:validate])
      return @upload unless @upload.errors.empty? && @upload.save(validate: @opts[:validate])

      # store the file and update its url
      File.open(@file.path) do |f|
        url = Discourse.store.store_upload(f, @upload)

        if url.present?
          @upload.url = url
          @upload.save!(validate: @opts[:validate])
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
    elsif pixels == 0 && @image_info.type.to_s != 'svg'
      @upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
    elsif max_image_pixels > 0 && pixels >= max_image_pixels * 2
      @upload.errors.add(:base, I18n.t("upload.images.larger_than_x_megapixels", max_image_megapixels: SiteSetting.max_image_megapixels * 2))
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
    return if @opts[:for_site_setting]
    return if filesize < MIN_CONVERT_TO_JPEG_BYTES_SAVED

    jpeg_tempfile = Tempfile.new(["image", ".jpg"])

    from = @file.path
    to = jpeg_tempfile.path

    OptimizedImage.ensure_safe_paths!(from, to)

    from = OptimizedImage.prepend_decoder!(from, nil, filename: "image.#{@image_info.type}")
    to = OptimizedImage.prepend_decoder!(to)

    opts = {}
    desired_quality = [SiteSetting.png_to_jpg_quality, SiteSetting.recompress_original_jpg_quality].compact.min
    target_quality = @upload.target_image_quality(from, desired_quality)
    opts = { quality: target_quality } if target_quality

    begin
      execute_convert(from, to, opts)
    rescue
      # retry with debugging enabled
      execute_convert(from, to, opts.merge(debug: true))
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

  def convert_heif_to_jpeg?
    File.extname(@filename).downcase.match?(/\.hei(f|c)$/)
  end

  def convert_heif!
    jpeg_tempfile = Tempfile.new(["image", ".jpg"])
    from = @file.path
    to = jpeg_tempfile.path
    OptimizedImage.ensure_safe_paths!(from, to)

    begin
      execute_convert(from, to)
    rescue
      # retry with debugging enabled
      execute_convert(from, to, { debug: true })
    end

    @file.respond_to?(:close!) ? @file.close! : @file.close
    @file = jpeg_tempfile
    extract_image_info!
  end

  MAX_CONVERT_FORMAT_SECONDS = 20
  def execute_convert(from, to, opts = {})
    command = [
      "convert",
      from,
      "-auto-orient",
      "-background", "white",
      "-interlace", "none",
      "-flatten"
    ]
    command << "-debug" << "all" if opts[:debug]
    command << "-quality" << opts[:quality].to_s if opts[:quality]
    command << to

    Discourse::Utils.execute_command(
      *command,
      failure_message: I18n.t("upload.png_to_jpg_conversion_failure_message"),
      timeout: MAX_CONVERT_FORMAT_SECONDS
    )
  end

  def should_alter_quality?
    return false if animated?

    desired_quality = @image_info.type == :png ? SiteSetting.png_to_jpg_quality : SiteSetting.recompress_original_jpg_quality
    @upload.target_image_quality(@file.path, desired_quality).present?
  end

  def should_downsize?
    max_image_size > 0 && filesize >= max_image_size && !animated?
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
        scale_image: true,
        raise_on_error: true
      )

      @file.respond_to?(:close!) ? @file.close! : @file.close
      @file = down_tempfile

      extract_image_info!

      return if filesize >= original_size || pixels == 0 || !should_downsize?
    end
  rescue
    @upload.errors.add(:base, I18n.t("upload.optimize_failure_message"))
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

  def clean_svg!
    doc = Nokogiri::XML(@file)
    doc.xpath(svg_allowlist_xpath).remove
    doc.xpath("//@*[starts-with(name(), 'on')]").remove
    doc.css('use').each do |use_el|
      if use_el.attr('href')
        use_el.remove_attribute('href') unless use_el.attr('href').starts_with?('#')
      end
      if use_el.attr('xlink:href')
        use_el.remove_attribute('xlink:href') unless use_el.attr('xlink:href').starts_with?('#')
      end
    end
    File.write(@file.path, doc.to_s)
    @file.rewind
  end

  def should_fix_orientation?
    # orientation is between 1 and 8, 1 being the default
    # cf. http://www.daveperrett.com/articles/2012/07/28/exif-orientation-handling-is-a-ghetto/
    @image_info.orientation.to_i > 1
  end

  MAX_FIX_ORIENTATION_TIME = 5
  def fix_orientation!
    path = @file.path

    OptimizedImage.ensure_safe_paths!(path)
    path = OptimizedImage.prepend_decoder!(path, nil, filename: "image.#{@image_info.type}")

    Discourse::Utils.execute_command('convert', path, '-auto-orient', path, timeout: MAX_FIX_ORIENTATION_TIME)

    extract_image_info!
  end

  def should_crop?
    return false if ['profile_background', 'card_background', 'custom_emoji'].include?(@opts[:type]) && animated?

    TYPES_TO_CROP.include?(@opts[:type])
  end

  def crop!
    max_pixel_ratio = Discourse::PIXEL_RATIOS.max
    filename_with_correct_ext = "image.#{@image_info.type}"

    case @opts[:type]
    when "avatar"
      width = height = Discourse.avatar_sizes.max
      OptimizedImage.resize(@file.path, @file.path, width, height, filename: filename_with_correct_ext)
    when "profile_background"
      max_width = 850 * max_pixel_ratio
      width, height = ImageSizer.resize(@image_info.size[0], @image_info.size[1], max_width: max_width, max_height: max_width)
      OptimizedImage.downsize(@file.path, @file.path, "#{width}x#{height}\>", filename: filename_with_correct_ext)
    when "card_background"
      max_width = 590 * max_pixel_ratio
      width, height = ImageSizer.resize(@image_info.size[0], @image_info.size[1], max_width: max_width, max_height: max_width)
      OptimizedImage.downsize(@file.path, @file.path, "#{width}x#{height}\>", filename: filename_with_correct_ext)
    when "custom_emoji"
      OptimizedImage.downsize(@file.path, @file.path, "100x100\>", filename: filename_with_correct_ext)
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

  def svg_allowlist_xpath
    @@svg_allowlist_xpath ||= "//*[#{ALLOWED_SVG_ELEMENTS.map { |e| "name()!='#{e}'" }.join(" and ") }]"
  end

  def add_metadata!
    @upload.for_private_message = true if @opts[:for_private_message]
    @upload.for_group_message   = true if @opts[:for_group_message]
    @upload.for_theme           = true if @opts[:for_theme]
    @upload.for_export          = true if @opts[:for_export]
    @upload.for_site_setting    = true if @opts[:for_site_setting]
    @upload.for_gravatar        = true if @opts[:for_gravatar]
  end

  private

  def animated?
    return @animated if @animated != nil

    @animated ||= begin
      is_animated = FastImage.animated?(@file)
      type = @image_info.type.to_s

      if is_animated != nil
        # FastImage will return nil if it cannot determine if animated
        is_animated
      elsif type == "gif" || type == "webp"
        # Only GIFs, WEBPs and a few other unsupported image types can be animated
        OptimizedImage.ensure_safe_paths!(@file.path)

        command = ["identify", "-format", "%n\\n", @file.path]
        frames = Discourse::Utils.execute_command(*command, timeout: Upload::MAX_IDENTIFY_SECONDS).to_i rescue 1

        frames > 1
      else
        false
      end
    end
  end

end
