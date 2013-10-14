# Post processing that we can do after a post has already been cooked.
# For example, inserting the onebox content, or image sizes/thumbnails.

require_dependency 'oneboxer'

class CookedPostProcessor
  include ActionView::Helpers::NumberHelper

  def initialize(post, opts={})
    @dirty = false
    @opts = opts
    @post = post
    @doc = Nokogiri::HTML::fragment(post.cooked)
    @size_cache = {}
    @has_been_uploaded_cache = {}
  end

  def post_process
    clean_up_reverse_index
    post_process_attachments
    post_process_images
    post_process_oneboxes
  end

  def clean_up_reverse_index
    PostUpload.delete_all(post_id: @post.id)
  end

  def post_process_attachments
    attachments.each do |attachment|
      href = attachment['href']
      attachment['href'] = relative_to_absolute(href)
      # update reverse index
      if upload = Upload.get_from_url(href)
        associate_to_post(upload)
      end
    end
  end

  def post_process_images
    images = extract_images
    return if images.blank?

    images.each do |img|
      if img['src'].present?
        # keep track of the original src
        src = img['src']
        # make sure the src is absolute (when working with locally uploaded files)
        img['src'] = relative_to_absolute(src)
        # make sure the img has proper width and height attributes
        update_dimensions!(img)
        # retrieve the associated upload, if any
        if upload = Upload.get_from_url(src)
          # update reverse index
          associate_to_post(upload)
        end
        # lightbox treatment
        convert_to_link!(img, upload)
        # mark the post as dirty whenever the src has changed
        @dirty |= src != img['src']
      end
    end

    # Extract the first image from the first post and use it as the 'topic image'
    extract_topic_image(images)
  end

  def post_process_oneboxes
    args = { post_id: @post.id }
    args[:invalidate_oneboxes] = true if @opts[:invalidate_oneboxes]
    # bake onebox content into the post
    result = Oneboxer.apply(@doc) do |url, element|
      Oneboxer.onebox(url, args)
    end
    # mark the post as dirty whenever a onebox as been baked
    @dirty |= result.changed?
  end

  def extract_images
    # do not extract images inside a onebox or a quote
    @doc.css("img") - @doc.css(".onebox-result img") - @doc.css(".quote img")
  end

  def relative_to_absolute(src)
    if src =~ /^\/[^\/]/
      Discourse.base_url_no_prefix + src
    else
      src
    end
  end

  def update_dimensions!(img)
    w, h = get_size_from_image_sizes(img['src'], @opts[:image_sizes]) || get_size(img['src'])
    # make sure we limit the size of the thumbnail
    w, h = ImageSizer.resize(w, h)
    # check whether the dimensions have changed
    @dirty = (img['width'].to_i != w) || (img['height'].to_i != h)
    # update the dimensions
    img['width'] = w
    img['height'] = h
  end

  def associate_to_post(upload)
    return if PostUpload.where(post_id: @post.id, upload_id: upload.id).count > 0
    PostUpload.create(post_id: @post.id, upload_id: upload.id)
  rescue ActiveRecord::RecordNotUnique
    # do not care if it's already associated
  end

  def optimize_image!(img)
    # TODO
    # 1) optimize using image_optim
    # 2) .png vs. .jpg (> 1.5x)
  end

  def convert_to_link!(img, upload=nil)
    src = img["src"]
    return unless src.present?

    width, height = img["width"].to_i, img["height"].to_i
    original_width, original_height = get_size(src)

    return if original_width.to_i <= width && original_height.to_i <= height
    return if original_width.to_i <= SiteSetting.max_image_width && original_height.to_i <= SiteSetting.max_image_height

    return if is_a_hyperlink(img)

    if upload
      # create a thumbnail
      upload.create_thumbnail!(width, height)
      # optimize image
      # TODO: optimize_image!(img)
    end

    add_lightbox!(img, original_width, original_height, upload)

    @dirty = true
  end

  def is_a_hyperlink(img)
    parent = img.parent
    while parent
      return if parent.name == "a"
      break unless parent.respond_to? :parent
      parent = parent.parent
    end
  end

  def add_lightbox!(img, original_width, original_height, upload=nil)
    # first, create a div to hold our lightbox
    lightbox = Nokogiri::XML::Node.new("div", @doc)
    img.add_next_sibling(lightbox)
    lightbox.add_child(img)

    # then, the link to our larger image
    a = Nokogiri::XML::Node.new("a", @doc)
    img.add_next_sibling(a)
    a["href"] = img['src']
    a["class"] = "lightbox"
    a.add_child(img)

    # replace the image by its thumbnail
    w = img["width"]
    h = img["height"]
    img['src'] = relative_to_absolute(upload.thumbnail(w, h).url) if upload && upload.has_thumbnail?(w, h)

    # then, some overlay informations
    meta = Nokogiri::XML::Node.new("div", @doc)
    meta["class"] = "meta"
    img.add_next_sibling(meta)

    filename = get_filename(upload, img['src'])
    informations = "#{original_width}x#{original_height}"
    informations << " #{number_to_human_size(upload.filesize)}" if upload

    meta.add_child create_span_node("filename", filename)
    meta.add_child create_span_node("informations", informations)
    meta.add_child create_span_node("expand")
  end

  def get_filename(upload, src)
    return File.basename(src) unless upload
    return upload.original_filename unless upload.original_filename =~ /^blob(\.png)?$/i
    return I18n.t('upload.pasted_image_filename')
  end

  def create_span_node(klass, content=nil)
    span = Nokogiri::XML::Node.new("span", @doc)
    span.content = content if content
    span['class'] = klass
    span
  end

  def extract_topic_image(images)
    if @post.post_number == 1
      img = images.first
      @post.topic.update_column :image_url, img['src'] if img['src'].present?
    end
  end

  def get_size_from_image_sizes(src, image_sizes)
    [image_sizes[src]["width"], image_sizes[src]["height"]] if image_sizes.present? && image_sizes[src].present?
  end

  def get_size(url)
    uri = url
    # make sure urls have a scheme (otherwise, FastImage will fail)
    uri = (SiteSetting.use_ssl? ? "https:" : "http:") + url if url && url.start_with?("//")
    return unless is_valid_image_uri?(uri)
    # we can *always* crawl our own images
    return unless SiteSetting.crawl_images? || Discourse.store.has_been_uploaded?(url)
    @size_cache[url] ||= FastImage.size(uri)
  rescue Zlib::BufError # FastImage.size raises BufError for some gifs
  end

  def is_valid_image_uri?(url)
    uri = URI.parse(url)
    %w(http https).include? uri.scheme
  rescue URI::InvalidURIError
  end

  def attachments
    attachments = @doc.css("a.attachment[href^=\"#{Discourse.store.absolute_base_url}\"]")
    attachments += @doc.css("a.attachment[href^=\"#{Discourse.store.relative_base_url}\"]") if Discourse.store.internal?
    attachments
  end

  def dirty?
    @dirty
  end

  def html
    @doc.try(:to_html)
  end

end
