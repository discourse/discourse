require "final_destination"
require "mini_mime"
require "open-uri"

class FileHelper

  def self.log(log_level, message)
    Rails.logger.public_send(
      log_level,
      "#{RailsMultisite::ConnectionManagement.current_db}: #{message}"
    )
  end

  def self.is_image?(filename)
    filename =~ images_regexp
  end

  class FakeIO
    attr_accessor :status
  end

  def self.download(url,
                    max_file_size:,
                    tmp_file_name:,
                    follow_redirect: false,
                    read_timeout: 5,
                    skip_rate_limit: false,
                    verbose: false)

    url = "https:" + url if url.start_with?("//")
    raise Discourse::InvalidParameters.new(:url) unless url =~ /^https?:\/\//

    tmp = nil

    fd = FinalDestination.new(
      url,
      max_redirects: follow_redirect ? 5 : 1,
      skip_rate_limit: skip_rate_limit,
      verbose: verbose
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

        # first run
        tmp_file_ext = File.extname(uri.path)

        if tmp_file_ext.blank? && response.content_type.present?
          ext = MiniMime.lookup_by_content_type(response.content_type)&.extension
          ext = "jpg" if ext == "jpe"
          tmp_file_ext = "." + ext if ext.present?
        end

        tmp = Tempfile.new([tmp_file_name, tmp_file_ext])
        tmp.binmode
      end

      tmp.write(chunk)

      throw :done if tmp.size > max_file_size
    end

    tmp&.rewind
    tmp
  end

  def self.optimize_image!(filename)
    ImageOptim.new(
      # GLOBAL
      timeout: 15,
      skip_missing_workers: true,
      # PNG
      optipng: { level: 2, strip: SiteSetting.strip_image_metadata },
      advpng: false,
      pngcrush: false,
      pngout: false,
      pngquant: false,
      # JPG
      jpegoptim: { strip: SiteSetting.strip_image_metadata ? "all" : "none" },
      jpegtran: false,
      jpegrecompress: false,
    ).optimize_image!(filename)
  end

  private

  def self.images
    @@images ||= Set.new %w{jpg jpeg png gif tif tiff bmp svg webp ico}
  end

  def self.images_regexp
    @@images_regexp ||= /\.(#{images.to_a.join("|")})$/i
  end

end
