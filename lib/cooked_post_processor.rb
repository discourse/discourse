# Post processing that we can do after a post has already been cooked. For
# example, inserting the onebox content, or image sizes.

require_dependency 'oneboxer'
require_dependency 'image_optimizer'

class CookedPostProcessor

  def initialize(post, opts={})
    @dirty = false
    @opts = opts
    @post = post
    @doc = Nokogiri::HTML::fragment(post.cooked)
    @size_cache = {}
  end

  def dirty?
    @dirty
  end

  # Bake onebox content into the post
  def post_process_oneboxes
    args = {post_id: @post.id}
    args[:invalidate_oneboxes] = true if @opts[:invalidate_oneboxes]

    result = Oneboxer.apply(@doc) do |url, element|
      Oneboxer.onebox(url, args)
    end
    @dirty ||= result.changed?
  end

  # First let's consider the images
  def post_process_images
    images = @doc.search("img")
    return unless images.present?

    images.each do |img|
      src = img['src']
      src = Discourse.base_url_no_prefix + src if src[0] == "/"

      if src.present?

        if img['width'].blank? || img['height'].blank?
          w, h = get_size_from_image_sizes(src, @opts[:image_sizes]) || image_dimensions(src)

          if w && h
            img['width'] = w.to_s
            img['height'] = h.to_s
            @dirty = true
          end
        end

        if src != img['src']
          img['src'] = src
          @dirty = true
        end

        convert_to_link!(img)
        img['src'] = optimize_image(img)

      end
    end

    # Extract the first image from the first post and use it as the 'topic image'
    if @post.post_number == 1
      img = images.first
      @post.topic.update_column :image_url, img['src'] if img['src'].present?
    end

  end

  def optimize_image(img)
    src = img["src"]
    return src

    # implementation notes: Sam
    #
    # I have disabled this for now, would like the following addressed.
    #
    # 1. We need a db record pointing the files on the file system to the post they are on,
    #   if we do not do that we have no way of purging any local optimised copies
    #
    # 2. We should be storing images in /uploads/site-name/_optimised ... it simplifies configuration
    #
    # 3. I don't want to have a folder with 10 million images, let split it so /uploads/site-name/_optimised/ABC/DEF/AAAAAAAA.jpg
    #
    # 4. We shoul confirm that that we test both saving as jpg and png and pick the more efficient format ... tricky to get right
    #
    # 5. All images should also be optimised using image_optim, it ensures that best compression is used
    #
    # 6. Admin screen should alert users of any missing dependencies (image magick, etc, and explain what it is for)
    #
    # 7. Optimise images should be a seperate site setting.

    # supports only local uploads
    return src if SiteSetting.enable_imgur? || SiteSetting.enable_s3_uploads?

    width, height = img["width"].to_i, img["height"].to_i

    ImageOptimizer.new(src).optimized_image_url(width, height)
  end

  def convert_to_link!(img)
    src = img["src"]
    width, height = img["width"].to_i, img["height"].to_i

    return unless src.present? && width > SiteSetting.auto_link_images_wider_than

    original_width, original_height = get_size(src)

    return unless original_width.to_i > width && original_height.to_i > height

    parent = img.parent
    while parent
      return if parent.name == "a"
      break unless parent.respond_to? :parent
      parent = parent.parent
    end

    # not a hyperlink so we can apply
    a = Nokogiri::XML::Node.new "a", @doc
    img.add_next_sibling(a)
    a["href"] = src
    a["class"] = "lightbox"
    a.add_child(img)
    @dirty = true

  end

  def get_size_from_image_sizes(src, image_sizes)
    if image_sizes.present?
      if dim = image_sizes[src]
        ImageSizer.resize(dim['width'], dim['height'])
      end
    end
  end

  def post_process
    return unless @doc.present?
    post_process_images
    post_process_oneboxes
  end

  def html
    @doc.try(:to_html)
  end

  def doc
    @doc
  end

  def get_size(url)
    # we need to find out whether it's an external image or an uploaded one
    # an external image would be: http://google.com/logo.png
    # an uploaded image would be: http://my.discourse.com/uploads/default/12345.png or http://my.cdn.com/uploads/default/12345.png
    uri = url
    # this will transform `http://my.discourse.com/uploads/default/12345.png` into a local uri
    uri = "#{Rails.root}/public#{url[Discourse.base_url.length..-1]}" if url.start_with?(Discourse.base_url)
    # this will do the same but when CDN has been defined in the configuration
    uri = "#{Rails.root}/public#{url[ActionController::Base.asset_host.length..-1]}" if ActionController::Base.asset_host && url.start_with?(ActionController::Base.asset_host)
    # return nil when it's an external image *and* crawling is disabled
    return nil unless SiteSetting.crawl_images? || uri[0] == "/"
    @size_cache[uri] ||= FastImage.size(uri)
  rescue Zlib::BufError
    # FastImage.size raises BufError for some gifs
    return nil
  end

  def get_image_uri(url)
    uri = URI.parse(url)
    if %w(http https).include?(uri.scheme)
      uri
    else
      nil
    end
  end

  # Retrieve the image dimensions for a url
  def image_dimensions(url)
    uri = get_image_uri(url)
    return nil unless uri
    w, h = get_size(url)
    ImageSizer.resize(w, h) if w && h
  end

end
