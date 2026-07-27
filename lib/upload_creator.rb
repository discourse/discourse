# frozen_string_literal: true

class UploadCreator
  TYPES_TO_CROP = %w[avatar card_background custom_emoji profile_background].each(&:freeze)

  ADMIN_ASSET_TYPES = %w[
    badge_image
    branding
    custom_emoji
    category_background
    category_background_dark
    category_logo
    category_logo_dark
    group_flair
  ].each(&:freeze)

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

    @image_type =
      begin
        DiscourseImage.type(@file)
      rescue DiscourseImage::Error
        nil
      end
    is_image = FileHelper.is_supported_image?(@filename)
    is_image ||= @image_type && FileHelper.is_supported_image?("test.#{@image_type}")
    is_image = false if @opts[:for_theme]
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
      if convert_heif_to_jpeg? && !external_upload_too_big
        convert_heif!
        is_image = FileHelper.is_supported_image?("test.#{@image_type}")
      end

      if is_image && !external_upload_too_big
        extract_image_info!
        return @upload if @upload.errors.present?

        if @image_type == :svg
          clean_svg!
        elsif @image_type == :ico
          convert_favicon_to_png!
        elsif !Rails.env.test? || @opts[:force_optimize]
          recompress_jpeg! if should_recompress_jpeg?
          convert_to_jpeg! if convert_png_to_jpeg?
          normalize_orientation! if should_normalize_orientation?
          crop! if should_crop?
          optimize! if should_optimize?
          downsize! if should_downsize?
          return @upload if is_still_too_big?
        end

        # conversion may have switched the type
        image_type = @image_type.to_s
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
          if SiteSetting.secure_uploads? || external_upload_too_big || is_thumbnail
            unique_hash
          else
            sha1
          end
        )
      @upload.original_sha1 = SiteSetting.secure_uploads? ? sha1 : nil
      @upload.url = ""
      @upload.origin = @opts[:origin][0...2000] if @opts[:origin]
      @upload.extension = image_type || File.extname(@filename)[1..10]

      if is_image && !external_upload_too_big
        w, h = @image_size

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
    begin
      @image_type = DiscourseImage.type(@file)
      @image_size =
        begin
          DiscourseImage.size(
            @file,
            timeout: @image_type == :svg ? Upload::MAX_IDENTIFY_SECONDS : 2,
          )
        rescue DiscourseImage::InvalidImageError
          raise if @image_type != :svg

          [0, 0]
        end
    rescue DiscourseImage::Error
      @image_type = @image_size = nil
    end

    if @image_type.nil?
      @upload.errors.add(:base, I18n.t("upload.images.not_supported_or_corrupted"))
    elsif filesize <= 0
      @upload.errors.add(:base, I18n.t("upload.empty"))
    elsif pixels == 0 && @image_type != :svg
      @upload.errors.add(:base, I18n.t("upload.images.size_not_found"))
    elsif @image_type != :svg && max_image_pixels > 0 && pixels >= max_image_pixels
      @upload.errors.add(
        :base,
        I18n.t(
          "upload.images.larger_than_x_megapixels",
          max_image_megapixels: SiteSetting.max_image_megapixels,
          original_filename: @upload.original_filename,
        ),
      )
    end
  end

  def convert_png_to_jpeg?
    @image_type == :png && !animated? && SiteSetting.ImageQuality.png_to_jpg_quality < 100
  end

  MIN_CONVERT_TO_JPEG_BYTES_SAVED = 75_000
  MIN_CONVERT_TO_JPEG_SAVING_RATIO = 0.70

  def convert_favicon_to_png!
    png_tempfile = Tempfile.new(%w[image .png])
    convert_image(input: @file.path, output: png_tempfile.path)
    replace_file(png_tempfile)
  end

  def convert_to_jpeg!
    return if !eligible_for_jpeg_reencoding?

    jpeg_tempfile = Tempfile.new(%w[image .jpg])
    maximum_quality = [
      SiteSetting.ImageQuality.png_to_jpg_quality,
      SiteSetting.ImageQuality.recompress_original_jpg_quality,
    ].compact.min
    convert_image(input: @file.path, output: jpeg_tempfile.path, maximum_quality: maximum_quality)
    keep_jpeg_candidate(jpeg_tempfile)
  end

  def should_recompress_jpeg?
    @image_type == :jpeg && !animated? &&
      SiteSetting.ImageQuality.recompress_original_jpg_quality < 100
  end

  def recompress_jpeg!
    return if !eligible_for_jpeg_reencoding?

    jpeg_tempfile = Tempfile.new(%w[image .jpg])
    FileUtils.cp(@file.path, jpeg_tempfile.path)
    changed =
      DiscourseImage.recompress!(
        jpeg_tempfile.path,
        maximum_quality: SiteSetting.ImageQuality.recompress_original_jpg_quality,
      )
    changed ? keep_jpeg_candidate(jpeg_tempfile) : jpeg_tempfile.close!
  end

  def eligible_for_jpeg_reencoding?
    @opts[:type] != "topic_og_image" && !@opts[:for_site_setting] &&
      !ADMIN_ASSET_TYPES.include?(@opts[:type]) && filesize >= MIN_CONVERT_TO_JPEG_BYTES_SAVED
  end

  def keep_jpeg_candidate(jpeg_tempfile)
    new_size = File.size(jpeg_tempfile.path)
    keep_jpeg = new_size < filesize * MIN_CONVERT_TO_JPEG_SAVING_RATIO
    keep_jpeg &&= (filesize - new_size) > MIN_CONVERT_TO_JPEG_BYTES_SAVED

    keep_jpeg ? replace_file(jpeg_tempfile) : jpeg_tempfile.close!
  end

  def convert_heif_to_jpeg?
    %i[heic heif].include?(@image_type)
  end

  def convert_heif!
    jpeg_tempfile = Tempfile.new(%w[image .jpg])
    convert_image(input: @file.path, output: jpeg_tempfile.path)
    replace_file(jpeg_tempfile)
  end

  def convert_image(input:, output:, maximum_quality: nil)
    DiscourseImage.convert(input: input, output: output, maximum_quality: maximum_quality)
  rescue DiscourseImage::Error => error
    raise error.class, I18n.t("upload.png_to_jpg_conversion_failure_message")
  end

  def replace_file(file)
    file.close
    file.open
    file.binmode
    @file.respond_to?(:close!) ? @file.close! : @file.close
    @file = file
    extract_image_info!
  end

  def should_normalize_orientation?
    DiscourseImage.orientation(@file) != :normal
  rescue DiscourseImage::Error
    false
  end

  def normalize_orientation!
    transformed_file = Tempfile.new(["oriented", ".#{@image_type}"])
    convert_image(input: @file.path, output: transformed_file.path)
    replace_file(transformed_file)
  end

  def should_downsize?
    max_image_size > 0 && filesize >= max_image_size && !animated?
  end

  def downsize!
    3.times do
      original_size = filesize
      down_tempfile = Tempfile.new(["down", ".#{@image_type}"])

      DiscourseImage.resize(
        input: @file.path,
        output: down_tempfile.path,
        scale: 0.5,
        allow_upscale: false,
      )

      replace_file(down_tempfile)

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
          original_filename: @upload.original_filename,
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
    doc.internal_subset&.remove
    doc.external_subset&.remove
    doc.xpath(svg_allowlist_xpath).remove
    doc.xpath("//@*[starts-with(name(), 'on')]").remove
    doc.traverse { |node| node.remove if node.type == Nokogiri::XML::Node::ENTITY_REF_NODE }
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

  def should_crop?
    if %w[profile_background card_background custom_emoji].include?(@opts[:type]) && animated?
      return false
    end

    TYPES_TO_CROP.include?(@opts[:type])
  end

  def crop!
    max_pixel_ratio = Discourse::PIXEL_RATIOS.max
    transformed_file = Tempfile.new(["transformed", ".#{@image_type}"])

    case @opts[:type]
    when "avatar"
      size = Discourse.avatar_sizes.max
      DiscourseImage.crop(
        input: @file.path,
        output: transformed_file.path,
        width: size,
        height: size,
      )
    when "profile_background"
      resize_background(output: transformed_file.path, max_width: 850 * max_pixel_ratio)
    when "card_background"
      resize_background(output: transformed_file.path, max_width: 590 * max_pixel_ratio)
    when "custom_emoji"
      DiscourseImage.resize(
        input: @file.path,
        output: transformed_file.path,
        width: 100,
        height: 100,
        allow_upscale: false,
      )
    end

    replace_file(transformed_file)
  end

  def resize_background(output:, max_width:)
    width, height =
      ImageSizer.resize(@image_size[0], @image_size[1], max_width: max_width, max_height: max_width)
    DiscourseImage.resize(
      input: @file.path,
      output: output,
      width: width,
      height: height,
      allow_upscale: false,
    )
  end

  def should_optimize?
    return false if !%i[jpeg png].include?(@image_type)
    return pixels < 2_000_000 if @image_type == :png

    true
  end

  def optimize!
    DiscourseImage.optimize!(@file.path)
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
    @image_size&.reduce(:*).to_i
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
    @upload.site_setting_name = @opts[:site_setting_name] if @opts[:site_setting_name]
    @upload.for_gravatar = true if @opts[:for_gravatar]
  end

  private

  def animated?
    return @animated if @animated != nil

    @animated ||=
      begin
        DiscourseImage.animated?(@file, timeout: Upload::MAX_IDENTIFY_SECONDS)
      rescue DiscourseImage::Error
        false
      end
  end

  def generate_fake_sha1_hash
    SecureRandom.hex(20)
  end
end
