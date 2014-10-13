require "open-uri"

class FileHelper

  def self.is_image?(filename)
    filename =~ images_regexp
  end

  def self.download(url, max_file_size, tmp_file_name, follow_redirect=false)
    raise Discourse::InvalidParameters.new(:url) unless url =~ /^https?:\/\//

    uri = URI.parse(url)
    extension = File.extname(uri.path)
    tmp = Tempfile.new([tmp_file_name, extension])

    File.open(tmp.path, "wb") do |f|
      downloaded = uri.open("rb", read_timeout: 5, redirect: follow_redirect)
      while f.size <= max_file_size && data = downloaded.read(max_file_size)
        f.write(data)
      end
      # tiny files are StringIO, no close! on them
      downloaded.close! if downloaded.respond_to? :close!
    end

    tmp
  end

  private

  def self.images
    @@images ||= Set.new ["jpg", "jpeg", "png", "gif", "tif", "tiff", "bmp", "svg", "webp"]
  end

  def self.images_regexp
    @@images_regexp ||= /\.(#{images.to_a.join("|")})$/i
  end

end
