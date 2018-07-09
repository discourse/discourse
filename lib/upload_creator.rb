require "fastimage"
require_dependency "image_sizer"

class UploadCreator

  TYPES_CONVERTED_TO_JPEG ||= %i{bmp png}

  TYPES_TO_CROP ||= %w{avatar card_background custom_emoji profile_background}.each(&:freeze)

  WHITELISTED_SVG_ELEMENTS ||= %w{
    circle clippath defs ellipse g line linearGradient path polygon polyline
    radialGradient rect stop svg text textpath tref tspan use
  }.each(&:freeze)

  # Available options
  #  - type (string)
  #  - content_type (string)
  #  - origin (string)
  #  - for_group_message (boolean)
  #  - for_theme (boolean)
  #  - for_private_message (boolean)
  #  - pasted (boolean)
  #  - for_export (boolean)
  def initialize(file, filename, opts = {})
    @file = file
    @filename = filename || ''
    @upload = Upload.new(original_filename: filename, filesize: 0)
    @opts = opts
  end

  def create_for(user_id)
    if filesize <= 0
      @upload.errors.add(:base, I18n.t("upload.empty"))
      return @upload
    end

    DistributedMutex.synchronize("upload_#{user_id}_#{@filename}") do
      if FileHelper.is_image?(@filename)
        extract_image_info!
        return @upload if @upload.errors.present?

        if @filename[/\.svg$/i]
          whitelist_svg!
        elsif !Rails.env.test?
          convert_to_jpeg! if should_convert_to_jpeg?
          downsize!        if should_downsize?

          return @upload   if is_still_too_big?

          fix_orientation! if should_fix_orientation?
          crop!            if should_crop?
          optimize!        if should_optimize?
        end
      end

      # compute the sha of the file
      sha1 = Upload.generate_digest(@file)

      # do we already have that upload?
      @upload = Upload.find_by(sha1: sha1)

      # make sure the previous upload has not failed
      if @upload && @upload.url.blank?
        @upload.destroy
        @upload = nil
      end

      # return the previous upload if any
      return @upload unless @upload.nil?

      # create the upload otherwise
      @upload = Upload.new
      @upload.user_id           = user_id
      @upload.original_filename = @filename
      @upload.filesize          = filesize
      @upload.sha1              = sha1
      @upload.url               = ""
      @upload.origin            = @opts[:origin][0...1000] if @opts[:origin]
      @upload.extension         = File.extname(@filename)[1..10]

      if FileHelper.is_image?(@filename)
        @upload.width, @upload.height = ImageSizer.resize(*@image_info.size)
      end

      @upload.for_private_message = true if @opts[:for_private_message]
      @upload.for_group_message   = true if @opts[:for_group_message]
      @upload.for_theme           = true if @opts[:for_theme]
      @upload.for_export          = true if @opts[:for_export]

      return @upload unless @upload.save

      # store the file and update its url
      File.open(@file.path) do |f|
        url = Discourse.store.store_upload(f, @upload, @opts[:content_type])
        if url.present?
          @upload.url = url
          @upload.save
        else
          @upload.errors.add(:url, I18n.t("upload.store_failure", upload_id: @upload.id, user_id: user_id))
        end
      end

      if @upload.errors.empty? && FileHelper.is_image?(@filename) && @opts[:type] == "avatar"
        Jobs.enqueue(:create_avatar_thumbnails, upload_id: @upload.id, user_id: user_id)
      end

      @upload
    end
  ensure
    @file&.close
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

  def should_convert_to_jpeg?
    return false if !TYPES_CONVERTED_TO_JPEG.include?(@image_info.type)
    return true  if @opts[:pasted]
    return false if SiteSetting.png_to_jpg_quality == 100
    pixels > MIN_PIXELS_TO_CONVERT_TO_JPEG
  end

  def convert_to_jpeg!
    jpeg_tempfile = Tempfile.new(["image", ".jpg"])

    OptimizedImage.ensure_safe_paths!(@file.path, jpeg_tempfile.path)

    begin
      execute_convert(@file, jpeg_tempfile)
    rescue
      # retry with debugging enabled
      execute_convert(@file, jpeg_tempfile, true)
    end

    # keep the JPEG if it's at least 15% smaller
    if File.size(jpeg_tempfile.path) < filesize * 0.85
      @file = jpeg_tempfile
      @filename = (File.basename(@filename, ".*").presence || I18n.t("image").presence || "image") + ".jpg"
      @opts[:content_type] = "image/jpeg"
      extract_image_info!
    else
      jpeg_tempfile&.close
    end
  end

  def execute_convert(input_file, output_file, debug = false)
    command = ['convert', input_file.path,
               '-auto-orient',
               '-background', 'white',
               '-interlace', 'none',
               '-flatten',
               '-quality', SiteSetting.png_to_jpg_quality.to_s]
    command << '-debug' << 'all' if debug
    command << output_file.path

    Discourse::Utils.execute_command(*command, failure_message: I18n.t("upload.png_to_jpg_conversion_failure_message"))
  end

  def should_downsize?
    max_image_size > 0 && filesize >= max_image_size
  end

  def downsize!
    3.times do
      original_size = filesize
      downsized_pixels = [pixels, max_image_pixels].min / 2
      OptimizedImage.downsize(@file.path, @file.path, "#{downsized_pixels}@", filename: @filename, allow_animation: allow_animation)
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
    File.write(@file.path, doc.to_s)
    @file.rewind
  end

  def should_fix_orientation?
    # orientation is between 1 and 8, 1 being the default
    # cf. http://www.daveperrett.com/articles/2012/07/28/exif-orientation-handling-is-a-ghetto/
    @image_info.orientation.to_i > 1
  end

  def fix_orientation!
    OptimizedImage.ensure_safe_paths!(@file.path)
    Discourse::Utils.execute_command('convert', @file.path, '-auto-orient', @file.path)
    extract_image_info!
  end

  def should_crop?
    TYPES_TO_CROP.include?(@opts[:type])
  end

  def crop!
    max_pixel_ratio = Discourse::PIXEL_RATIOS.max

    case @opts[:type]
    when "avatar"
      width = height = Discourse.avatar_sizes.max
      OptimizedImage.resize(@file.path, @file.path, width, height, filename: @filename, allow_animation: allow_animation)
    when "profile_background"
      max_width = 850 * max_pixel_ratio
      width, height = ImageSizer.resize(@image_info.size[0], @image_info.size[1], max_width: max_width, max_height: max_width)
      OptimizedImage.downsize(@file.path, @file.path, "#{width}x#{height}\\>", filename: @filename, allow_animation: allow_animation)
    when "card_background"
      max_width = 590 * max_pixel_ratio
      width, height = ImageSizer.resize(@image_info.size[0], @image_info.size[1], max_width: max_width, max_height: max_width)
      OptimizedImage.downsize(@file.path, @file.path, "#{width}x#{height}\\>", filename: @filename, allow_animation: allow_animation)
    when "custom_emoji"
      OptimizedImage.downsize(@file.path, @file.path, "100x100\\>", filename: @filename, allow_animation: allow_animation)
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
