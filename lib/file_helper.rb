class FileHelper

  def self.is_image?(filename)
    filename =~ images_regexp
  end

  def self.download(url, max_file_size, tmp_file_name)
    raise Discourse::InvalidParameters unless url =~ /^https?:\/\//

    extension = File.extname(URI.parse(url).path)
    tmp = Tempfile.new([tmp_file_name, extension])

    File.open(tmp.path, "wb") do |f|
      downloaded = open(url, "rb", read_timeout: 5)
      while f.size <= max_file_size && data = downloaded.read(max_file_size)
        f.write(data)
      end
      downloaded.close!
    end

    tmp
  end

  private

  def self.images
    @@images ||= Set.new ["jpg", "jpeg", "png", "gif", "tif", "tiff", "bmp"]
  end

  def self.images_regexp
    @@images_regexp ||= /\.(#{images.to_a.join("|").gsub(".", "\.")})$/i
  end

end
