require "open-uri"

class FileHelper

  def self.is_image?(filename)
    filename =~ images_regexp
  end

  def self.download(url, max_file_size, tmp_file_name, follow_redirect=false)
    raise Discourse::InvalidParameters.new(:url) unless url =~ /^https?:\/\//

    uri = parse_url(url)
    extension = File.extname(uri.path)
    tmp = Tempfile.new([tmp_file_name, extension])

    File.open(tmp.path, "wb") do |f|
      downloaded = uri.open("rb", read_timeout: 5, redirect: follow_redirect, allow_redirections: :all)
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
    @@images ||= Set.new ["jpg", "jpeg", "png", "gif", "tif", "tiff", "bmp", "svg", "webp"]
  end

  def self.images_regexp
    @@images_regexp ||= /\.(#{images.to_a.join("|")})$/i
  end

  # HACK to support underscores in URLs
  # cf. http://stackoverflow.com/a/18938253/11983
  def self.parse_url(url)
    URI.parse(url)
  rescue URI::InvalidURIError
    host = url.match(".+\:\/\/([^\/]+)")[1]
    uri = URI.parse(url.sub(host, 'valid-host'))
    uri.instance_variable_set("@host", host)
    uri
  end

end
