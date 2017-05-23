require "open-uri"
require "final_destination"

class FileHelper

  def self.is_image?(filename)
    filename =~ images_regexp
  end

  def self.download(url, max_file_size, tmp_file_name, follow_redirect=false, read_timeout=5)
    url = "https:" + url if url.start_with?("//")
    raise Discourse::InvalidParameters.new(:url) unless url =~ /^https?:\/\//

    uri = FinalDestination.new(url, max_redirects: follow_redirect ? 5 : 1).resolve
    return unless uri.present?

    extension = File.extname(uri.path)
    tmp = Tempfile.new([tmp_file_name, extension])

    File.open(tmp.path, "wb") do |f|
      downloaded = uri.open("rb", read_timeout: read_timeout)
      while f.size <= max_file_size && data = downloaded.read(512.kilobytes)
        f.write(data)
      end
      # tiny files are StringIO, no close! on them
      downloaded.try(:close!) rescue nil
    end

    tmp
  end

  private

  def self.images
    @@images ||= Set.new %w{jpg jpeg png gif tif tiff bmp svg webp ico}
  end

  def self.images_regexp
    @@images_regexp ||= /\.(#{images.to_a.join("|")})$/i
  end

end
