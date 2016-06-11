# Post processing that we can do after a post has already been cooked.
# For example, inserting the onebox content, or image sizes/thumbnails.

require_dependency 'url_helper'
require_dependency 'pretty_text'

class CookedPostProcessor
  include ActionView::Helpers::NumberHelper

  def initialize(post, opts={})
    @dirty = false
    @opts = opts
    @post = post
    @previous_cooked = (@post.cooked || "").dup
    # NOTE: we re-cook the post here in order to prevent timing issues with edits
    # cf. https://meta.discourse.org/t/edit-of-rebaked-post-doesnt-show-in-html-only-in-raw/33815/6
    @cooking_options = post.cooking_options || opts[:cooking_options] || {}
    @cooking_options[:topic_id] = post.topic_id
    @cooking_options = @cooking_options.symbolize_keys

    analyzer = post.post_analyzer
    @doc = Nokogiri::HTML::fragment(analyzer.cook(post.raw, @cooking_options))
    @has_oneboxes = analyzer.found_oneboxes?
    @size_cache = {}
  end

  def post_process(bypass_bump = false)
    DistributedMutex.synchronize("post_process_#{@post.id}") do
      keep_reverse_index_up_to_date
      post_process_images
      post_process_oneboxes
      optimize_urls
      pull_hotlinked_images(bypass_bump)
      grant_badges
      extract_links
    end
  end

  # onebox may have added some links, so extract them now
  def extract_links
    TopicLink.extract_from(@post)
    QuotedPost.extract_from(@post)
  end

  def has_emoji?
    (@doc.css("img.emoji") - @doc.css(".quote img")).size > 0
  end

  def grant_badges
    return unless Guardian.new.can_see?(@post)

    BadgeGranter.grant(Badge.find(Badge::FirstEmoji), @post.user, post_id: @post.id) if has_emoji?
    BadgeGranter.grant(Badge.find(Badge::FirstOnebox), @post.user, post_id: @post.id) if @has_oneboxes
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

    update_topic_image
  end

  def extract_images
    # all image with a src attribute
    @doc.css("img[src]") -
    # minus, data images
    @doc.css("img[src^='data']") -
    # minus, emojis
    @doc.css("img.emoji") -
    # minus, image inside oneboxes
    oneboxed_images -
    # minus, images inside quotes
    @doc.css(".quote img")
  end

  def extract_images_for_topic
    # all image with a src attribute
    @doc.css("img[src]") -
    # minus, emojis
    @doc.css("img.emoji") -
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
    return [w, h] unless w <= 0 || h <= 0
    # if only width or height are specified attempt to scale image
    if w > 0 || h > 0
      w = w.to_f
      h = h.to_f

      return unless original_image_size = get_size(img["src"])
      original_width, original_height = original_image_size.map(&:to_f)

      if w > 0
        ratio = w/original_width
        [w.floor, (original_height*ratio).floor]
      else
        ratio = h/original_height
        [(original_width*ratio).floor, h.floor]
      end
    end
  end

  def get_size_from_image_sizes(src, image_sizes)
    return unless image_sizes.present?
    image_sizes.each do |image_size|
      url, size = image_size[0], image_size[1]
      if url && url.include?(src) &&
         size && size["width"].to_i > 0 && size["height"].to_i > 0
        return [size["width"], size["height"]]
      end
    end
  end

  def get_size(url)
    return @size_cache[url] if @size_cache.has_key?(url)

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

  # only crop when the image is taller than 16:9
  # we only use 95% of that to allow for a small margin
  MIN_RATIO_TO_CROP ||= (9.0 / 16.0) * 0.95

  def convert_to_link!(img)
    src = img["src"]
    return unless src.present?

    width, height = img["width"].to_i, img["height"].to_i
    original_width, original_height = get_size(src)

    # can't reach the image...
    if original_width.nil? ||
       original_height.nil? ||
       original_width == 0 ||
       original_height == 0
      Rails.logger.info "Can't reach '#{src}' to get its dimension."
      return
    end

    return if original_width.to_i <= width && original_height.to_i <= height
    return if original_width.to_i <= SiteSetting.max_image_width && original_height.to_i <= SiteSetting.max_image_height

    return if is_a_hyperlink?(img)

    crop = false
    if original_width.to_f / original_height.to_f < MIN_RATIO_TO_CROP
      crop = true
      width, height = ImageSizer.crop(original_width, original_height)
      img["width"] = width
      img["height"] = height
    end

    if upload = Upload.get_from_url(src)
      upload.create_thumbnail!(width, height, crop)
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

    a["title"] = img["title"] || filename

    meta.add_child create_span_node("filename", img["title"] || filename)
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

  def update_topic_image
    if @post.is_first_post?
      img = extract_images_for_topic.first
      @post.topic.update_column(:image_url, img["src"][0...255]) if img["src"].present?
    end
  end

  def post_process_oneboxes
    args = {
      post_id: @post.id,
      invalidate_oneboxes: !!@opts[:invalidate_oneboxes],
    }

    # apply oneboxes
    Oneboxer.apply(@doc, topic_id: @post.topic_id) { |url|
      @has_oneboxes = true
      Oneboxer.onebox(url, args)
    }

    # make sure we grab dimensions for oneboxed images
    oneboxed_images.each { |img| limit_size!(img) }

    # respect nofollow admin settings
    if !@cooking_options[:omit_nofollow] && SiteSetting.add_rel_nofollow_to_user_content
      PrettyText.add_rel_nofollow_to_user_content(@doc)
    end
  end

  def optimize_urls
    # when login is required, attachments can't be on the CDN
    if SiteSetting.login_required
      @doc.css("a.attachment[href]").each do |a|
        href = a["href"].to_s
        a["href"] = UrlHelper.schemaless UrlHelper.absolute(href, nil) if UrlHelper.is_local(href)
      end
    end

    %w{href data-download-href}.each do |selector|
      @doc.css("a[#{selector}]").each do |a|
        href = a["#{selector}"].to_s
        a["#{selector}"] = UrlHelper.schemaless UrlHelper.absolute(href) if UrlHelper.is_local(href)
      end
    end

    @doc.css("img[src]").each do |img|
      src = img["src"].to_s
      img["src"] = UrlHelper.schemaless UrlHelper.absolute(src) if UrlHelper.is_local(src)
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
    delay = SiteSetting.editing_grace_period + 1
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
    notify_about_low_disk_space

    true
  end

  def notify_about_low_disk_space
    SystemMessage.create_from_system_user(Discourse.site_contact_user, :download_remote_images_disabled)
  end

  def available_disk_space
    100 - `df -P #{Rails.root}/public/uploads | tail -1 | tr -s ' ' | cut -d ' ' -f 5`.to_i
  end

  def dirty?
    @previous_cooked != html
  end

  def html
    @doc.try(:to_html)
  end

end
