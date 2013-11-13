class AvatarUploadService

  attr_accessor :source
  attr_reader :filesize, :file

  def initialize(file, source)
    @source = source
    @file , @filesize = construct(file)
  end

  def construct(file)
    case source
    when :url
      build_from_url(file)
    when :image
      [file, File.size(file.tempfile)]
    end
  end

  private

  def build_from_url(url)
    temp = ::UriAdapter.new(url)
    return temp.build_uploaded_file, temp.file_size
  end

end

class AvatarUploadPolicy

  def initialize(avatar)
    @avatar = avatar
  end

  def max_size_kb
    SiteSetting.max_image_size_kb.kilobytes
  end

  def too_big?
    @avatar.filesize > max_size_kb
  end

end
