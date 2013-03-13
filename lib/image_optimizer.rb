# This class is used to download and optimize images.
#
# I have not had a chance to implement me, and will not for about 3 weeks.
# If you are looking for a small project this simple API would be a good stint.
#
# Implement the following methods. With tests, the tests are a HUGE PITA cause
# network, disk and external dependencies are involved.

class ImageOptimizer
  attr_accessor :url, :root_dir
  # url is a url of an image ex:
  # 'http://site.com/image.png'
  # '/uploads/site/image.png'
  #
  # root_dir is the path where we
  # store optimized images
  def initialize(opts = {})
    @url = opts[:url]
    @root_dir = opts[:root_dir]
  end

  # attempt to refresh the original image, if refreshed
  #  remove old downsized copies
  def refresh_local!
  end

  # clear all local copies of the images
  def clear_local!
  end

  # yield a list of relative paths to local images cached
  def each_local
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
  def optimized_image_path(width=nil, height=nil)
  end

end
