# Post processing that we can do after a post has already been cooked. For
# example, inserting the onebox content, or image sizes.

require_dependency 'oneboxer'

class CookedPostProcessor
  require 'open-uri'

  def initialize(post, opts={})
    @dirty = false
    @opts = opts
    @post = post
    @doc = Nokogiri::HTML(post.cooked)
    @size_cache = {}
  end

  def dirty?
    @dirty
  end

  # Bake onebox content into the post
  def post_process_oneboxes
    args = {post_id: @post.id}
    args[:invalidate_oneboxes] = true if @opts[:invalidate_oneboxes]

    Oneboxer.each_onebox_link(@doc) do |url, element|
      onebox = Oneboxer.onebox(url, args)
      if onebox
        element.swap onebox
        @dirty = true
      end
    end
  end

  # First let's consider the images
  def post_process_images
    images = @doc.search("img")
    return unless images.present?

    # Extract the first image from the first post and use it as the 'topic image'
    if @post.post_number == 1
      img = images.first
      @post.topic.update_column :image_url, img['src'] if img['src'].present?
    end

    images.each do |img|
      src = img['src']
      src = Discourse.base_url + src if src[0] == "/"

      if src.present? && (img['width'].blank? || img['height'].blank?)

        w,h =
          get_size_from_image_sizes(src, @opts[:image_sizes]) ||
          image_dimensions(src)

        if w && h
          img['width'] = w.to_s
          img['height'] = h.to_s
          @dirty = true
        end
      end

      if src.present?
        if src != img['src']
          img['src'] = src
          @dirty = true
        end
        convert_to_link!(img)
        img.set_attribute('src', optimize_image(src))
      end

    end
  end

  def optimize_image(src)
    # uri = get_image_uri(src)
    # uri.open(read_timeout: 20) do |f|
    #
    # end

    src
  end

  def convert_to_link!(img)
    src = img["src"]
    width = img["width"].to_i
    height = img["height"].to_i

    return unless src.present? && width > SiteSetting.auto_link_images_wider_than

    original_width, original_height  = get_size(src)

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

  def get_size(url)
    return nil unless SiteSetting.crawl_images? || url.start_with?(Discourse.base_url)
    @size_cache[url] ||= FastImage.size(url)
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
