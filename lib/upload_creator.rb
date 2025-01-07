# frozen_string_literal: true

require "fastimage"

class UploadCreator
  TYPES_TO_CROP = %w[avatar card_background custom_emoji profile_background].each(&:freeze)

  ALLOWED_SVG_ELEMENTS = %w[
    circle
    clipPath
    defs
    ellipse
    feGaussianBlur
    filter
    g
    line
    linearGradient
    marker
    path
    polygon
    polyline
    radialGradient
    rect
    stop
    style
    svg
    text
    textPath
    tref
    tspan
    use
  ].each(&:freeze)

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
    @filesize = @opts[:filesize] if @opts[:external_upload_too_big]
    @opts[:validate] = (
      if opts[:skip_validations].present?
        !ActiveRecord::Type::Boolean.new.cast(opts[:skip_validations])
      else
        true
      end
    )
  end

  def create_for(user_id)
    if filesize <= 0
      @upload.errors.add(:base, I18n.t("upload.empty"))
      return @upload
    end

    @image_info = FastImage.new(@file)
    begin
      @image_info.fetch
    rescue StandardError
    end

    if @opts[:for_theme]
      is_image = false
    else
      is_image = FileHelper.is_supported_image?(@filename)
      is_image ||= @image_info.type && FileHelper.is_supported_image?("test.#{@image_info.type}")
    end

    is_thumbnail = SiteSetting.video_thumbnails_enabled && @opts[:type] == "thumbnail"

    # If this is present then it means we are creating an upload record from
    # an external_upload_stub and the file is > ExternalUploadManager::DOWNLOAD_LIMIT,
    # so we have not downloaded it to a tempfile. no modifications can be made to the
    # file in this case because it does not exist; we simply move it to its new location
    # in S3
    #
    # FIXME: I've added a bunch of external_upload_too_big checks littered
    # throughout the UploadCreator code. It would be better to have two separate
    # classes with shared methods, rather than doing all these checks all over the
    # place. Needs a refactor.
    external_upload_too_big = @opts[:external_upload_too_big]
    sha1_before_changes = Upload.generate_digest(@file) if @file

    DistributedMutex.synchronize("upload_#{user_id}_#{@filename}") do
      # We need to convert HEIFs early because FastImage does not consider them as images
      if convert_heif_to_jpeg? && !external_upload_too_big
        convert_heif!
        is_image = FileHelper.is_supported_image?("test.#{@image_info.type}")
      end

      if is_image && !external_upload_too_big
        extract_image_info!
        return @upload if @upload.errors.present?

        if @image_info.type == :svg
          clean_svg!
        elsif @image_info.type == :ico
          convert_favicon_to_png!
        elsif !Rails.env.test? || @opts[:force_optimize]
          convert_to_jpeg! if convert_png_to_jpeg? || should_alter_quality?
          fix_orientation! if should_fix_orientation?
          crop! if should_crop?
          optimize! if should_optimize?
          downsize! if should_downsize?
          return @upload if is_still_too_big?
        end

        # conversion may have switched the type
        image_type = @image_info.type.to_s
      end

      # compute the sha of the file and generate a unique hash
      # which is only used for secure uploads
      sha1 = Upload.generate_digest(@file) if !external_upload_too_big
      unique_hash = generate_fake_sha1_hash if SiteSetting.secure_uploads ||
        external_upload_too_big || is_thumbnail

      # we do not check for duplicate uploads if secure uploads is
      # enabled because we use a unique access hash to differentiate
      # between uploads instead of the sha1, and to get around various
      # access/permission issues for uploads
      # We do not check for duplicate uploads for video thumbnails because
      # their filename needs to match with their corresponding video. This also
      # enables rebuilding the html on a topic to regenerate a thumbnail.
      if !SiteSetting.secure_uploads && !external_upload_too_big && !is_thumbnail
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

      if is_image && !external_upload_too_big
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
      @upload.user_id = user_id
      @upload.original_filename = fixed_original_filename || @filename
      @upload.filesize = filesize
      @upload.sha1 =
        (
          if (SiteSetting.secure_uploads? || external_upload_too_big || is_thumbnail)
            unique_hash
          else
            sha1
          end
        )
      @upload.original_sha1 = SiteSetting.secure_uploads? ? sha1 : nil
      @upload.url = ""
      @upload.origin = @opts[:origin][0...1000] if @opts[:origin]
      @upload.extension = image_type || File.extname(@filename)[1..10]

      if is_image && !external_upload_too_big
        if @image_info.type.to_s == "svg"
          w, h = [0, 0]

          # identify can behave differently depending on how it's compiled and
          # what programs (e.g. inkscape) are installed on your system.
          # 'MSVG:' forces ImageMagick to use internal routines and behave
          # consistently whether it's running from our docker container or not
          begin
            w, h =
              Discourse::Utils
                .execute_command(
                  "identify",
                  "-ping",
                  "-format",
                  "%w %h",
                  "MSVG:#{@file.path}",
                  timeout: Upload::MAX_IDENTIFY_SECONDS,
                )
                .split(" ")
                .map(&:to_i)
          rescue StandardError
            # use default 0, 0
          end
        else
          w, h = @image_info.size
        end

        @upload.thumbnail_width, @upload.thumbnail_height = ImageSizer.resize(w, h)
        @upload.width, @upload.height = w, h
        @upload.animated = animated?
        @upload.calculate_dominant_color!(@file.path)
      end

      add_metadata!

      if SiteSetting.secure_uploads
        secure, reason =
          UploadSecurity.new(@upload, @opts.merge(creating: true)).should_be_secure_with_reason
        attrs = @upload.secure_params(secure, reason, "upload creator")
        @upload.assign_attributes(attrs)
      end

      # Callbacks using this event to validate the upload or the file must add errors to the
      # upload errors object.
      #
      # Can't do any validation of the file if external_upload_too_big because we don't have
      # the actual file.
      if !external_upload_too_big
        DiscourseEvent.trigger(:before_upload_creation, @file, is_image, @upload, @opts[:validate])
      end
      return @upload unless @upload.errors.empty? && @upload.save(validate: @opts[:validate])

      should_move = false
      upload_changed =
        if external_upload_too_big
          false
        else
          Upload.generate_digest(@file) != sha1_before_changes
        end

      store = Discourse.store

      if @opts[:existing_external_upload_key] && store.external?
        should_move = external_upload_too_big || !upload_changed
      end

      if should_move
        # move the file in the store instead of reuploading
        url =
          store.move_existing_stored_upload(
            existing_external_upload_key: @opts[:existing_external_upload_key],
            upload: @upload,
          )
      else
        # store the file and update its url
        File.open(@file.path) { |f| url = store.store_upload(f, @upload) }
        if @opts[:existing_external_upload_key]
          store.delete_file(@opts[:existing_external_upload_key])
        end
      end

      if url.present?
        @upload.url = url
        @upload.save!(validate: @opts[:validate])
      else
        @upload.errors.add(
          :url,
          I18n.t("upload.store_failure", upload_id: @upload.id, user_id: user_id),
        )
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
    @image_info = FastImage.new(@file)
    begin
      @image_info.fetch
    rescue StandardError
    end
    @file.rewind

    if !@image_info.type
      @upload.errors.add(:base, I18n.t("upload.images.not_supported_or_corrupted"))
    elsif filesize <= 0
      @upload.errors.add(:base, I18n.t("upload.empty"))
    elsif pixels == 0 && @image_info.type.to_s != "svg"
      @upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
    elsif max_image_pixels > 0 && pixels >= max_image_pixels
      @upload.errors.add(
        :base,
        I18n.t(
          "upload.images.larger_than_x_megapixels",
          max_image_megapixels: SiteSetting.max_image_megapixels,
        ),
      )
    end
  end

  MIN_PIXELS_TO_CONVERT_TO_JPEG = 1280 * 720

  def convert_png_to_jpeg?
    return false unless @image_info.type == :png
    return true if @opts[:pasted]
    return false if SiteSetting.png_to_jpg_quality == 100
    pixels > MIN_PIXELS_TO_CONVERT_TO_JPEG
  end

  MIN_CONVERT_TO_JPEG_BYTES_SAVED = 75_000
  MIN_CONVERT_TO_JPEG_SAVING_RATIO = 0.70

  def convert_favicon_to_png!
    png_tempfile = Tempfile.new(%w[image .png])

    from = @file.path
    to = png_tempfile.path

    OptimizedImage.ensure_safe_paths!(from, to)

    from = OptimizedImage.prepend_decoder!(from, nil, filename: "image.#{@image_info.type}")
    to = OptimizedImage.prepend_decoder!(to)

    from = "#{from}[-1]" # We only want the last(largest) image of the .ico file

    opts = { flatten: false } # Preserve transparency

    begin
      execute_convert(from, to, opts)
    rescue StandardError
      # retry with debugging enabled
      execute_convert(from, to, opts.merge(debug: true))
    end

    @file.respond_to?(:close!) ? @file.close! : @file.close
    @file = png_tempfile
    extract_image_info!
  end

  def convert_to_jpeg!
    return if @opts[:for_site_setting]
    return if filesize < MIN_CONVERT_TO_JPEG_BYTES_SAVED

    jpeg_tempfile = Tempfile.new(%w[image .jpg])

    from = @file.path
    to = jpeg_tempfile.path

    OptimizedImage.ensure_safe_paths!(from, to)

    from = OptimizedImage.prepend_decoder!(from, nil, filename: "image.#{@image_info.type}")
    to = OptimizedImage.prepend_decoder!(to)

    opts = {}
    desired_quality = [
      SiteSetting.png_to_jpg_quality,
      SiteSetting.recompress_original_jpg_quality,
    ].compact.min
    target_quality = @upload.target_image_quality(from, desired_quality)
    opts = { quality: target_quality } if target_quality

    begin
      execute_convert(from, to, opts)
    rescue StandardError
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
    File.extname(@filename).downcase.match?(/\.hei(f|c)\z/)
  end

  def convert_heif!
    jpeg_tempfile = Tempfile.new(%w[image .jpg])
    from = @file.path
    to = jpeg_tempfile.path
    OptimizedImage.ensure_safe_paths!(from, to)

    begin
      execute_convert(from, to)
    rescue StandardError
      # retry with debugging enabled
      execute_convert(from, to, { debug: true })
    end

    @file.respond_to?(:close!) ? @file.close! : @file.close
    @file = jpeg_tempfile
    extract_image_info!
  end

  MAX_CONVERT_FORMAT_SECONDS = 20
  def execute_convert(from, to, opts = {})
    command = ["magick", from, "-auto-orient", "-background", "white", "-interlace", "none"]
    command << "-flatten" unless opts[:flatten] == false
    command << "-debug" << "all" if opts[:debug]
    command << "-quality" << opts[:quality].to_s if opts[:quality]
    command << to

    Discourse::Utils.execute_command(
      *command,
      failure_message: I18n.t("upload.png_to_jpg_conversion_failure_message"),
      timeout: MAX_CONVERT_FORMAT_SECONDS,
    )
  end

  def should_alter_quality?
    return false if animated?

    desired_quality =
      (
        if @image_info.type == :png
          SiteSetting.png_to_jpg_quality
        else
          SiteSetting.recompress_original_jpg_quality
        end
      )
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

      OptimizedImage.downsize(from, to, "50%", scale_image: true, raise_on_error: true)

      @file.respond_to?(:close!) ? @file.close! : @file.close
      @file = down_tempfile

      extract_image_info!

      return if filesize >= original_size || pixels == 0 || !should_downsize?
    end
  rescue StandardError
    @upload.errors.add(:base, I18n.t("upload.optimize_failure_message"))
  end

  def is_still_too_big?
    if max_image_pixels > 0 && pixels >= max_image_pixels
      @upload.errors.add(
        :base,
        I18n.t(
          "upload.images.larger_than_x_megapixels",
          max_image_megapixels: SiteSetting.max_image_megapixels,
        ),
      )
      true
    elsif max_image_size > 0 && filesize >= max_image_size
      @upload.errors.add(
        :base,
        I18n.t(
          "upload.images.too_large_humanized",
          max_size: ActiveSupport::NumberHelper.number_to_human_size(max_image_size),
        ),
      )
      true
    else
      false
    end
  end

  def clean_svg!
    doc = Nokogiri.XML(@file)
    doc.xpath(svg_allowlist_xpath).remove
    doc.xpath("//@*[starts-with(name(), 'on')]").remove
    doc
      .css("use")
      .each do |use_el|
        if use_el.attr("href")
          use_el.remove_attribute("href") unless use_el.attr("href").starts_with?("#")
        end
        use_el.remove_attribute("xlink:href")
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

    Discourse::Utils.execute_command(
      "magick",
      path,
      "-auto-orient",
      path,
      timeout: MAX_FIX_ORIENTATION_TIME,
    )

    extract_image_info!
  end

  def should_crop?
    if %w[profile_background card_background custom_emoji].include?(@opts[:type]) && animated?
      return false
    end

    TYPES_TO_CROP.include?(@opts[:type])
  end

  def crop!
    max_pixel_ratio = Discourse::PIXEL_RATIOS.max
    filename_with_correct_ext = "image.#{@image_info.type}"

    case @opts[:type]
    when "avatar"
      width = height = Discourse.avatar_sizes.max
      OptimizedImage.resize(
        @file.path,
        @file.path,
        width,
        height,
        filename: filename_with_correct_ext,
      )
    when "profile_background"
      max_width = 850 * max_pixel_ratio
      width, height =
        ImageSizer.resize(
          @image_info.size[0],
          @image_info.size[1],
          max_width: max_width,
          max_height: max_width,
        )
      OptimizedImage.downsize(
        @file.path,
        @file.path,
        "#{width}x#{height}\>",
        filename: filename_with_correct_ext,
      )
    when "card_background"
      max_width = 590 * max_pixel_ratio
      width, height =
        ImageSizer.resize(
          @image_info.size[0],
          @image_info.size[1],
          max_width: max_width,
          max_height: max_width,
        )
      OptimizedImage.downsize(
        @file.path,
        @file.path,
        "#{width}x#{height}\>",
        filename: filename_with_correct_ext,
      )
    when "custom_emoji"
      OptimizedImage.downsize(
        @file.path,
        @file.path,
        "100x100\>",
        filename: filename_with_correct_ext,
      )
    end

    extract_image_info!
  end

  def should_optimize?
    # GIF is too slow (plus, we'll soon be converting them to MP4)
    # Optimizing SVG is useless
    return false if @file.path =~ /\.(gif|svg)\z/i
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
    @filesize || File.size?(@file.path).to_i
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
    @@svg_allowlist_xpath ||=
      "//*[#{ALLOWED_SVG_ELEMENTS.map { |e| "name()!='#{e}'" }.join(" and ")}]"
  end

  def add_metadata!
    @upload.for_private_message = true if @opts[:for_private_message]
    @upload.for_group_message = true if @opts[:for_group_message]
    @upload.for_theme = true if @opts[:for_theme]
    @upload.for_export = true if @opts[:for_export]
    @upload.for_site_setting = true if @opts[:for_site_setting]
    @upload.for_gravatar = true if @opts[:for_gravatar]
  end

  private

  def animated?
    return @animated if @animated != nil

    @animated ||=
      begin
        is_animated = FastImage.animated?(@file)
        type = @image_info.type.to_s

        if is_animated != nil
          # FastImage will return nil if it cannot determine if animated
          is_animated
        elsif %w[gif webp avif].include?(type)
          # Only GIFs, WEBPs and a few other unsupported image types can be animated
          OptimizedImage.ensure_safe_paths!(@file.path)

          command = ["identify", "-ping", "-format", "%n\\n", @file.path]
          frames =
            begin
              Discourse::Utils.execute_command(*command, timeout: Upload::MAX_IDENTIFY_SECONDS).to_i
            rescue StandardError
              1
            end

          frames > 1
        else
          false
        end
      end
  end

  def generate_fake_sha1_hash
    SecureRandom.hex(20)
  end
end
