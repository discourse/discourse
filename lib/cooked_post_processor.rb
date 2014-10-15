# Post processing that we can do after a post has already been cooked.
# For example, inserting the onebox content, or image sizes/thumbnails.

require_dependency 'url_helper'

class CookedPostProcessor
  include ActionView::Helpers::NumberHelper
  include UrlHelper

  def initialize(post, opts={})
    @dirty = false
    @opts = opts
    @post = post
    @previous_cooked = (@post.cooked || "").dup
    @doc = Nokogiri::HTML::fragment(post.cooked)
    @size_cache = {}
  end

  def post_process(bypass_bump = false)
    keep_reverse_index_up_to_date
    post_process_images
    post_process_oneboxes
    optimize_urls
    pull_hotlinked_images(bypass_bump)
  end

  def keep_reverse_index_up_to_date
    upload_ids = Set.new

    @doc.css("a[href]").each do |a|
      href = a["href"].to_s
      if upload = Upload.get_from_url(href)
        upload_ids << upload.id
      end
    end

    @doc.css("img[src]").each do |img|
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
      limit_size!(img)
      convert_to_link!(img)
    end

    update_topic_image(images)
  end

  def extract_images
    # all image with a src attribute
    @doc.css("img[src]") -
    # minus, data images
    @doc.css("img[src^='data']") -
    # minus, image inside oneboxes
    oneboxed_images -
    # minus, images inside quotes
    @doc.css(".quote img")
  end

  def oneboxed_images
    @doc.css(".onebox-result img, .onebox img")
  end

  def limit_size!(img)
    # retrieve the size from
    #  1) the width/height attributes
    #  2) the dimension from the preview (image_sizes)
    #  3) the dimension of the original image (HTTP request)
    w, h = get_size_from_attributes(img) ||
           get_size_from_image_sizes(img["src"], @opts[:image_sizes]) ||
           get_size(img["src"])
    # limit the size of the thumbnail
    img["width"], img["height"] = ImageSizer.resize(w, h)
  end

  def get_size_from_attributes(img)
    w, h = img["width"].to_i, img["height"].to_i
    return [w, h] if w > 0 && h > 0
  end

  def get_size_from_image_sizes(src, image_sizes)
    return unless image_sizes.present?
    image_sizes.each do |image_size|
      url, size = image_size[0], image_size[1]
      return [size["width"], size["height"]] if url && size && url.include?(src)
    end
  end

  def get_size(url)
    absolute_url = url
    absolute_url = Discourse.base_url_no_prefix + absolute_url if absolute_url =~ /^\/[^\/]/
    # FastImage fails when there's no scheme
    absolute_url = SiteSetting.scheme + ":" + absolute_url if absolute_url.start_with?("//")
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
    end

    add_lightbox!(img, original_width, original_height, upload)
  end

  def is_a_hyperlink?(img)
    parent = img.parent
    while parent
      return true if parent.name == "a"
      break unless parent.respond_to? :parent
      parent = parent.parent
    end
    false
  end

  def add_lightbox!(img, original_width, original_height, upload=nil)
    # first, create a div to hold our lightbox
    lightbox = Nokogiri::XML::Node.new("div", @doc)
    lightbox["class"] = "lightbox-wrapper"
    img.add_next_sibling(lightbox)
    lightbox.add_child(img)

    # then, the link to our larger image
    a = Nokogiri::XML::Node.new("a", @doc)
    img.add_next_sibling(a)

    if upload && Discourse.store.internal?
      a["data-download-href"] = Discourse.store.download_url(upload)
    end

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

    a["title"] = filename

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

    # apply oneboxes
    Oneboxer.apply(@doc) { |url| Oneboxer.onebox(url, args) }

    # make sure we grab dimensions for oneboxed images
    oneboxed_images.each { |img| limit_size!(img) }
  end

  def optimize_urls
    %w{href data-download-href}.each do |selector|
      @doc.css("a[#{selector}]").each do |a|
        href = a["#{selector}"].to_s
        a["#{selector}"] = schemaless absolute(href) if is_local(href)
      end
    end

    @doc.css("img[src]").each do |img|
      src = img["src"].to_s
      img["src"] = schemaless absolute(src) if is_local(src)
    end
  end

  def pull_hotlinked_images(bypass_bump = false)
    # is the job enabled?
    return unless SiteSetting.download_remote_images_to_local?
    # have we enough disk space?
    return if disable_if_low_on_disk_space
    # we only want to run the job whenever it's changed by a user
    return if @post.last_editor_id == Discourse.system_user.id
    # make sure no other job is scheduled
    Jobs.cancel_scheduled_job(:pull_hotlinked_images, post_id: @post.id)
    # schedule the job
    delay = SiteSetting.ninja_edit_window + 1
    Jobs.enqueue_in(delay.seconds.to_i, :pull_hotlinked_images, post_id: @post.id, bypass_bump: bypass_bump)
  end

  def disable_if_low_on_disk_space
    return false if available_disk_space >= SiteSetting.download_remote_images_threshold

    SiteSetting.download_remote_images_to_local = false
    # log the site setting change
    reason = I18n.t("disable_remote_images_download_reason")
    staff_action_logger = StaffActionLogger.new(Discourse.system_user)
    staff_action_logger.log_site_setting_change("download_remote_images_to_local", true, false, { details: reason })
    # also send a private message to the site contact user
    SystemMessage.create_from_system_user(Discourse.site_contact_user, :download_remote_images_disabled)

    true
  end

  def available_disk_space
    100 - `df -l . | tail -1 | tr -s ' ' | cut -d ' ' -f 5`.to_i
  end

  def dirty?
    @previous_cooked != html
  end

  def html
    @doc.try(:to_html)
  end

end
