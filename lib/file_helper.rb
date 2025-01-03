# frozen_string_literal: true

require "final_destination"
require "mini_mime"
require "open-uri"

class FileHelper
  def self.log(log_level, message)
    Rails.logger.public_send(
      log_level,
      "#{RailsMultisite::ConnectionManagement.current_db}: #{message}",
    )
  end

  def self.is_supported_image?(filename)
    filename.match?(supported_images_regexp)
  end

  def self.is_supported_video?(filename)
    filename.match?(supported_video_regexp)
  end

  def self.is_supported_audio?(filename)
    filename.match?(supported_audio_regexp)
  end

  def self.is_inline_image?(filename)
    filename.match?(inline_images_regexp)
  end

  def self.is_svg?(filename)
    filename.match?(/\.svg\z/i)
  end

  def self.is_supported_media?(filename)
    filename.match?(supported_media_regexp)
  end

  def self.is_supported_playable_media?(filename)
    filename.match?(supported_playable_media_regexp)
  end

  class FakeIO
    attr_accessor :status
  end

  def self.download(
    url,
    max_file_size:,
    tmp_file_name:,
    follow_redirect: false,
    read_timeout: 5,
    skip_rate_limit: false,
    verbose: false,
    validate_uri: true,
    retain_on_max_file_size_exceeded: false,
    include_port_in_host_header: false,
    extra_headers: {}
  )
    url = "https:" + url if url.start_with?("//")
    raise Discourse::InvalidParameters.new(:url) unless url =~ %r{\Ahttps?://}

    tmp = nil

    fd =
      FinalDestination.new(
        url,
        max_redirects: follow_redirect ? 5 : 0,
        skip_rate_limit: skip_rate_limit,
        verbose: verbose,
        validate_uri: validate_uri,
        timeout: read_timeout,
        include_port_in_host_header: include_port_in_host_header,
        headers: extra_headers,
      )

    fd.get do |response, chunk, uri|
      if tmp.nil?
        # error handling
        if uri.blank?
          if response.code.to_i >= 400
            # attempt error API compatibility
            io = FakeIO.new
            io.status = [response.code, ""]
            raise OpenURI::HTTPError.new("#{response.code} Error", io)
          else
            log(:error, "FinalDestination did not work for: #{url}") if verbose
            throw :done
          end
        end

        if response.content_type.present?
          ext = MiniMime.lookup_by_content_type(response.content_type)&.extension
          ext = "jpg" if ext == "jpe"
          tmp_file_ext = "." + ext if ext.present?
        end

        tmp_file_ext ||= File.extname(uri.path)
        tmp = Tempfile.new([tmp_file_name, tmp_file_ext])
        tmp.binmode
      end

      tmp.write(chunk)

      if tmp.size > max_file_size
        unless retain_on_max_file_size_exceeded
          tmp.close
          tmp = nil
        end

        throw :done
      end
    end

    tmp&.rewind
    tmp
  end

  def self.optimize_image!(filename, allow_pngquant: false)
    image_optim(
      allow_pngquant: allow_pngquant,
      strip_image_metadata: SiteSetting.strip_image_metadata,
    ).optimize_image!(filename)
  end

  def self.image_optim(allow_pngquant: false, strip_image_metadata: true)
    # memoization is critical, initializing an ImageOptim object is very expensive
    # sometimes up to 200ms searching for binaries and looking at versions
    memoize("image_optim", allow_pngquant, strip_image_metadata) do
      pngquant_options = false
      pngquant_options = { allow_lossy: true } if allow_pngquant

      ImageOptim.new(
        # GLOBAL
        timeout: 15,
        skip_missing_workers: true,
        # PNG
        oxipng: {
          level: 3,
          strip: strip_image_metadata,
        },
        optipng: false,
        advpng: false,
        pngcrush: false,
        pngout: false,
        pngquant: pngquant_options,
        # JPG
        jpegoptim: {
          strip: strip_image_metadata ? "all" : "none",
        },
        jpegtran: false,
        jpegrecompress: false,
        # Skip looking for gifsicle, svgo binaries
        gifsicle: false,
        svgo: false,
      )
    end
  end

  def self.memoize(*args)
    (@memoized ||= {})[args] ||= yield
  end

  def self.supported_gravatar_extensions
    @@supported_gravatar_images ||= Set.new(%w[jpg jpeg png gif])
  end

  def self.supported_images
    @@supported_images ||= Set.new %w[jpg jpeg png gif svg ico webp avif]
  end

  def self.inline_images
    # SVG cannot safely be shown as a document
    @@inline_images ||= supported_images - %w[svg]
  end

  def self.supported_audio
    @@supported_audio ||= Set.new %w[mp3 ogg oga opus wav m4a m4b m4p m4r aac flac]
  end

  def self.supported_video
    @@supported_video ||= Set.new %w[mov mp4 webm ogv m4v 3gp avi mpeg]
  end

  def self.supported_video_regexp
    @@supported_video_regexp ||= /\.(#{supported_video.to_a.join("|")})\z/i
  end

  def self.supported_audio_regexp
    @@supported_audio_regexp ||= /\.(#{supported_audio.to_a.join("|")})\z/i
  end

  def self.supported_images_regexp
    @@supported_images_regexp ||= /\.(#{supported_images.to_a.join("|")})\z/i
  end

  def self.inline_images_regexp
    @@inline_images_regexp ||= /\.(#{inline_images.to_a.join("|")})\z/i
  end

  def self.supported_media_regexp
    @@supported_media_regexp ||=
      begin
        media = supported_images | supported_audio | supported_video
        /\.(#{media.to_a.join("|")})\z/i
      end
  end

  def self.supported_playable_media_regexp
    @@supported_playable_media_regexp ||=
      begin
        media = supported_audio | supported_video
        /\.(#{media.to_a.join("|")})\z/i
      end
  end
end
