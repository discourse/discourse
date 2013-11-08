# Post processing that we can do after a post has already been cooked.
# For example, inserting the onebox content, or image sizes/thumbnails.

require_dependency "oneboxer"

class CookedPostProcessor
  include ActionView::Helpers::NumberHelper

  def initialize(post, opts={})
    @dirty = false
    @opts = opts
    @post = post
    @doc = Nokogiri::HTML::fragment(post.cooked)
    @size_cache = {}
  end

  def post_process
    keep_reverse_index_up_to_date
    post_process_images
    post_process_oneboxes
    optimize_urls
    pull_hotlinked_images
  end

  def keep_reverse_index_up_to_date
    upload_ids = Set.new

    @doc.search("a").each do |a|
      href = a["href"].to_s
      if upload = Upload.get_from_url(href)
        upload_ids << upload.id
      end
    end

    @doc.search("img").each do |img|
      src = img["src"].to_s
      if upload = Upload.get_from_url(src)
        upload_ids << upload.id
      end
    end

    values = upload_ids.map{ |u| "(#{@post.id},#{u})" }.join(",")
    PostUpload.transaction do
      PostUpload.delete_all(post_id: @post.id)
      if upload_ids.length > 0
        PostUpload.exec_sql("INSERT INTO post_uploads (post_id, upload_id) VALUES #{values}")
      end
    end
  end

  def post_process_images
    images = extract_images
    return if images.blank?

    images.each do |img|
      src, width, height = img["src"], img["width"], img["height"]
      limit_size!(img)
      convert_to_link!(img)
      @dirty |= (src != img["src"]) || (width.to_i != img["width"].to_i) || (height.to_i != img["height"].to_i)
    end

    update_topic_image(images)
  end

  def extract_images
    # do not extract images inside oneboxes or quotes
    @doc.css("img") - @doc.css(".onebox-result img") - @doc.css(".quote img")
  end

  def limit_size!(img)
    w, h = get_size_from_image_sizes(img["src"], @opts[:image_sizes]) || get_size(img["src"])
    # limit the size of the thumbnail
    img["width"], img["height"] = ImageSizer.resize(w, h)
  end

  def get_size_from_image_sizes(src, image_sizes)
    return unless image_sizes.present?
    image_sizes.each do |image_size|
      url, size = image_size[0], image_size[1]
      return [size["width"], size["height"]] if url.include?(src)
    end
  end

  def get_size(url)
    absolute_url = url
    absolute_url = Discourse.base_url_no_prefix + absolute_url if absolute_url =~ /^\/[^\/]/
    # FastImage fails when there's no scheme
    absolute_url = (SiteSetting.use_ssl? ? "https:" : "http:") + absolute_url if absolute_url.start_with?("//")
    return unless is_valid_image_url?(absolute_url)
    # we can *always* crawl our own images
    return unless SiteSetting.crawl_images? || Discourse.store.has_been_uploaded?(url)
    @size_cache[url] ||= FastImage.size(absolute_url)
  rescue Zlib::BufError # FastImage.size raises BufError for some gifs
  end

  def is_valid_image_url?(url)
    uri = URI.parse(url)
    %w(http https).include? uri.scheme
  rescue URI::InvalidURIError
  end

  def convert_to_link!(img)
    src = img["src"]
    return unless src.present?

    width, height = img["width"].to_i, img["height"].to_i
    original_width, original_height = get_size(src)

    return if original_width.to_i <= width && original_height.to_i <= height
    return if original_width.to_i <= SiteSetting.max_image_width && original_height.to_i <= SiteSetting.max_image_height

    return if is_a_hyperlink?(img)

    if upload = Upload.get_from_url(src)
      upload.create_thumbnail!(width, height)
      # TODO: optimize_image!(img)
    end

    add_lightbox!(img, original_width, original_height, upload)

    @dirty = true
  end

  def is_a_hyperlink?(img)
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
    a["href"] = img["src"]
    a["class"] = "lightbox"
    a.add_child(img)

    # replace the image by its thumbnail
    w, h = img["width"].to_i, img["height"].to_i
    img["src"] = upload.thumbnail(w, h).url if upload && upload.has_thumbnail?(w, h)

    # then, some overlay informations
    meta = Nokogiri::XML::Node.new("div", @doc)
    meta["class"] = "meta"
    img.add_next_sibling(meta)

    filename = get_filename(upload, img["src"])
    informations = "#{original_width}x#{original_height}"
    informations << " #{number_to_human_size(upload.filesize)}" if upload

    meta.add_child create_span_node("filename", filename)
    meta.add_child create_span_node("informations", informations)
    meta.add_child create_span_node("expand")
  end

  def get_filename(upload, src)
    return File.basename(src) unless upload
    return upload.original_filename unless upload.original_filename =~ /^blob(\.png)?$/i
    return I18n.t("upload.pasted_image_filename")
  end

  def create_span_node(klass, content=nil)
    span = Nokogiri::XML::Node.new("span", @doc)
    span.content = content if content
    span["class"] = klass
    span
  end

  def update_topic_image(images)
    if @post.post_number == 1
      img = images.first
      @post.topic.update_column(:image_url, img["src"]) if img["src"].present?
    end
  end

  def post_process_oneboxes
    args = {
      post_id: @post.id,
      invalidate_oneboxes: !!@opts[:invalidate_oneboxes],
    }

    result = Oneboxer.apply(@doc) do |url, element|
      Oneboxer.onebox(url, args)
    end

    @dirty |= result.changed?
  end

  def optimize_urls
    @doc.search("a").each do |a|
      href = a["href"].to_s
      a["href"] = schemaless absolute(href) if is_local(href)
    end

    @doc.search("img").each do |img|
      src = img["src"].to_s
      img["src"] = schemaless absolute(src) if is_local(src)
    end
  end

  def is_local(url)
    Discourse.store.has_been_uploaded?(url) || url =~ /^\/assets\//
  end

  def absolute(url)
    url =~ /^\/[^\/]/ ? (Discourse.asset_host || Discourse.base_url_no_prefix) + url : url
  end

  def schemaless(url)
    url.gsub(/^https?:/, "")
  end

  def pull_hotlinked_images
    # we don't want to run the job if we're not allowed to crawl images
    return unless SiteSetting.crawl_images?
    # we only want to run the job whenever it's changed by a user
    return if @post.updated_by == Discourse.system_user
    # make sure no other job is scheduled
    Jobs.cancel_scheduled_job(:pull_hotlinked_images, post_id: @post.id)
    # schedule the job
    delay = SiteSetting.ninja_edit_window + 1
    Jobs.enqueue_in(delay.seconds.to_i, :pull_hotlinked_images, post_id: @post.id)
  end

  def dirty?
    @dirty
  end

  def html
    @doc.try(:to_html)
  end

end
