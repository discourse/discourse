#
# This class is used to download and optimize images.
#

require 'image_sorcery'
require 'digest/sha1'
require 'open-uri'

class ImageOptimizer
  attr_accessor :url

  # url is a url of an image ex:
  # 'http://site.com/image.png'
  # '/uploads/site/image.png'
  def initialize(url)
    @url = url
    # make sure directories exists
    FileUtils.mkdir_p downloads_dir
    FileUtils.mkdir_p optimized_dir
  end

  # return the path of an optimized image,
  #  if already cached return cached, else download and cache
  #   at the original size.
  # if size is specified return a resized image
  # if height or width are nil maintain aspect ratio
  #
  # Optimised image is the "most efficient" storage for an image
  #  at the basic level it runs through image_optim https://github.com/toy/image_optim
  #  it also has a failsafe that converts jpg to png or the opposite. if jpg size is 1.5*
  #  as efficient as png it flips formats.
  def optimized_image_url (width = nil, height = nil)
    begin
      unless has_been_uploaded?
        return @url unless SiteSetting.crawl_images?
        # download the file if it hasn't been cached yet
        download! unless File.exists?(cached_path)
      end

      # resize the image using Image Magick
      result = ImageSorcery.new(cached_path).convert(optimized_path, resize: "#{width}x#{height}")
      return optimized_url if result
      @url
    rescue
      @url
    end
  end

private

  def public_dir
    @public_dir ||= "#{Rails.root}/public"
  end

  def downloads_dir
    @downloads_dir ||= "#{public_dir}/downloads/#{RailsMultisite::ConnectionManagement.current_db}"
  end

  def optimized_dir
    @optimized_dir ||= "#{public_dir}/images/#{RailsMultisite::ConnectionManagement.current_db}"
  end

  def has_been_uploaded?
    @url.start_with?(Discourse.base_url_no_prefix)
  end

  def cached_path
    @cached_path ||= if has_been_uploaded?
      "#{public_dir}#{@url[Discourse.base_url_no_prefix.length..-1]}"
    else
      "#{downloads_dir}/#{file_name(@url)}"
    end
  end

  def optimized_path
    @optimized_path ||= "#{optimized_dir}/#{file_name(cached_path)}"
  end

  def file_name (uri)
    image_info = FastImage.new(uri)
    name = Digest::SHA1.hexdigest(uri)[0,16]
    name << ".#{image_info.type}"
    name
  end

  def download!
    File.open(cached_path, "wb") do |f|
      f.write open(@url, "rb", read_timeout: 20).read
    end
  end

  def optimized_url
    @optimized_url ||= Discourse.base_url_no_prefix + "/images/#{RailsMultisite::ConnectionManagement.current_db}/#{file_name(cached_path)}"
  end

end
