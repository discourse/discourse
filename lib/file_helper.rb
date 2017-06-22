require "final_destination"
require "mini_mime"
require "open-uri"

class FileHelper

  def self.is_image?(filename)
    filename =~ images_regexp
  end

  def self.download(url,
                    max_file_size:,
                    tmp_file_name:,
                    follow_redirect: false,
                    read_timeout: 5,
                    skip_rate_limit: false)

    url = "https:" + url if url.start_with?("//")
    raise Discourse::InvalidParameters.new(:url) unless url =~ /^https?:\/\//

    uri = FinalDestination.new(
      url,
      max_redirects: follow_redirect ? 5 : 1,
      skip_rate_limit: skip_rate_limit
    ).resolve
    return unless uri.present?

    downloaded = uri.open("rb", read_timeout: read_timeout)

    extension = File.extname(uri.path)

    if extension.blank? && downloaded.content_type.present?
      ext = MiniMime.lookup_by_content_type(downloaded.content_type)&.extension
      ext = "jpg" if ext == "jpe"
      extension = "." + ext if ext.present?
    end

    tmp = Tempfile.new([tmp_file_name, extension])

    File.open(tmp.path, "wb") do |f|
      while f.size <= max_file_size && data = downloaded.read(512.kilobytes)
        f.write(data)
      end
    end

    tmp
  ensure
    downloaded&.close! rescue nil
  end

  private

  def self.images
    @@images ||= Set.new %w{jpg jpeg png gif tif tiff bmp svg webp ico}
  end

  def self.images_regexp
    @@images_regexp ||= /\.(#{images.to_a.join("|")})$/i
  end

end
