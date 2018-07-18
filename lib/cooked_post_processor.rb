# Post processing that we can do after a post has already been cooked.
# For example, inserting the onebox content, or image sizes/thumbnails.

require_dependency 'url_helper'
require_dependency 'pretty_text'
require_dependency 'quote_comparer'

class CookedPostProcessor
  include ActionView::Helpers::NumberHelper

  attr_reader :cooking_options, :doc

  def initialize(post, opts = {})
    @dirty = false
    @opts = opts
    @post = post
    @previous_cooked = (@post.cooked || "").dup
    # NOTE: we re-cook the post here in order to prevent timing issues with edits
    # cf. https://meta.discourse.org/t/edit-of-rebaked-post-doesnt-show-in-html-only-in-raw/33815/6
    @cooking_options = post.cooking_options || opts[:cooking_options] || {}
    @cooking_options[:topic_id] = post.topic_id
    @cooking_options = @cooking_options.symbolize_keys
    @cooking_options[:omit_nofollow] = true if post.omit_nofollow?
    @cooking_options[:cook_method] = post.cook_method

    analyzer = post.post_analyzer
    @doc = Nokogiri::HTML::fragment(analyzer.cook(post.raw, @cooking_options))
    @has_oneboxes = analyzer.found_oneboxes?
    @size_cache = {}
  end

  def post_process(bypass_bump = false)
    DistributedMutex.synchronize("post_process_#{@post.id}") do
      DiscourseEvent.trigger(:before_post_process_cooked, @doc, @post)
      post_process_oneboxes
      post_process_images
      post_process_quotes
      keep_reverse_index_up_to_date
      optimize_urls
      update_post_image
      enforce_nofollow
      pull_hotlinked_images(bypass_bump)
      grant_badges
      DiscourseEvent.trigger(:post_process_cooked, @doc, @post)
      nil
    end
  end

  def has_emoji?
    (@doc.css("img.emoji") - @doc.css(".quote img")).size > 0
  end

  def grant_badges
    return unless Guardian.new.can_see?(@post)

    BadgeGranter.grant(Badge.find(Badge::FirstEmoji), @post.user, post_id: @post.id) if has_emoji?
    BadgeGranter.grant(Badge.find(Badge::FirstOnebox), @post.user, post_id: @post.id) if @has_oneboxes
    BadgeGranter.grant(Badge.find(Badge::FirstReplyByEmail), @post.user, post_id: @post.id) if @post.is_reply_by_email?
  end

  def keep_reverse_index_up_to_date
    upload_ids = []

    @doc.css("a/@href", "img/@src").each do |media|
      if upload = Upload.get_from_url(media.value)
        upload_ids << upload.id
      end
    end

    upload_ids |= downloaded_images.values.select { |id| Upload.exists?(id) }

    values = upload_ids.map { |u| "(#{@post.id},#{u})" }.join(",")
    PostUpload.transaction do
      PostUpload.where(post_id: @post.id).delete_all
      if upload_ids.size > 0
        DB.exec("INSERT INTO post_uploads (post_id, upload_id) VALUES #{values}")
      end
    end
  end

  def post_process_images
    extract_images.each do |img|
      src = img["src"].sub(/^https?:/i, "")
      if large_images.include?(src)
        add_large_image_placeholder!(img)
      elsif broken_images.include?(src)
        add_broken_image_placeholder!(img)
      else
        limit_size!(img)
        convert_to_link!(img)
      end
    end
  end

  def post_process_quotes
    @doc.css("aside.quote").each do |q|
      post_number = q['data-post']
      topic_id = q['data-topic']
      if topic_id && post_number
        comparer = QuoteComparer.new(
          topic_id.to_i,
          post_number.to_i,
          q.css('blockquote').text
        )

        if comparer.modified?
          q['class'] = ((q['class'] || '') + " quote-modified").strip
        end
      end
    end
  end

  def add_large_image_placeholder!(img)
    url = img["src"]

    is_hyperlinked = is_a_hyperlink?(img)

    placeholder = create_node("div", "large-image-placeholder")
    img.add_next_sibling(placeholder)
    placeholder.add_child(img)

    a = create_link_node(nil, url, true)
    img.add_next_sibling(a)

    span = create_span_node("url", url)
    a.add_child(span)
    span.add_previous_sibling(create_icon_node("image"))
    span.add_next_sibling(create_span_node("help", I18n.t("upload.placeholders.too_large", max_size_kb: SiteSetting.max_image_size_kb)))

    # Only if the image is already linked
    if is_hyperlinked
      parent = placeholder.parent
      parent.add_next_sibling(placeholder)

      if parent.name == 'a' && parent["href"].present?
        if url == parent["href"]
          parent.remove
        else
          parent["class"] = "link"
          a.add_previous_sibling(parent)

          lspan = create_span_node("url", parent["href"])
          parent.add_child(lspan)
          lspan.add_previous_sibling(create_icon_node("link"))
        end
      end
    end

    img.remove
  end

  def add_broken_image_placeholder!(img)
    img.name = "span"
    img.set_attribute("class", "broken-image fa fa-chain-broken")
    img.set_attribute("title", I18n.t("post.image_placeholder.broken"))
    img.remove_attribute("src")
    img.remove_attribute("width")
    img.remove_attribute("height")
  end

  def large_images
    @large_images ||= JSON.parse(@post.custom_fields[Post::LARGE_IMAGES].presence || "[]") rescue []
  end

  def broken_images
    @broken_images ||= JSON.parse(@post.custom_fields[Post::BROKEN_IMAGES].presence || "[]") rescue []
  end

  def downloaded_images
    @downloaded_images ||= JSON.parse(@post.custom_fields[Post::DOWNLOADED_IMAGES].presence || "{}") rescue {}
  end

  def extract_images
    # all images with a src attribute
    @doc.css("img[src]") -
    # minus data images
    @doc.css("img[src^='data']") -
    # minus emojis
    @doc.css("img.emoji") -
    # minus oneboxed images
    oneboxed_images -
    # minus images inside quotes
    @doc.css(".quote img")
  end

  def extract_images_for_post
    # all images with a src attribute
    @doc.css("img[src]") -
    # minus emojis
    @doc.css("img.emoji") -
    # minus images inside quotes
    @doc.css(".quote img")
  end

  def oneboxed_images
    @doc.css(".onebox-body img, .onebox img")
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
        ratio = w / original_width
        [w.floor, (original_height * ratio).floor]
      else
        ratio = h / original_height
        [(original_width * ratio).floor, h.floor]
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

    return unless absolute_url

    # FastImage fails when there's no scheme
    absolute_url = SiteSetting.scheme + ":" + absolute_url if absolute_url.start_with?("//")
    return unless is_valid_image_url?(absolute_url)

    # we can *always* crawl our own images
    return unless SiteSetting.crawl_images? || Discourse.store.has_been_uploaded?(url)

    @size_cache[url] = FastImage.size(absolute_url)
  rescue Zlib::BufError, URI::InvalidURIError, URI::InvalidComponentError, OpenSSL::SSL::SSLError
    # FastImage.size raises BufError for some gifs, leave it.
  end

  def is_valid_image_url?(url)
    uri = URI.parse(url)
    %w(http https).include? uri.scheme
  rescue URI::InvalidURIError
  end

  def convert_to_link!(img)
    src = img["src"]
    return if src.blank? || is_a_hyperlink?(img) || is_svg?(img)

    width, height = img["width"].to_i, img["height"].to_i
    # TODO: store original dimentions in db
    original_width, original_height = (get_size(src) || [0, 0]).map(&:to_i)

    # can't reach the image...
    if original_width == 0 || original_height == 0
      Rails.logger.info "Can't reach '#{src}' to get its dimension."
      return
    end

    return if original_width <= width && original_height <= height
    return if original_width <= SiteSetting.max_image_width && original_height <= SiteSetting.max_image_height

    crop   = SiteSetting.min_ratio_to_crop > 0
    crop &&= original_width.to_f / original_height.to_f < SiteSetting.min_ratio_to_crop

    if crop
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
      parent = parent.parent if parent.respond_to?(:parent)
    end
    false
  end

  def add_lightbox!(img, original_width, original_height, upload = nil)
    # first, create a div to hold our lightbox
    lightbox = create_node("div", "lightbox-wrapper")
    img.add_next_sibling(lightbox)
    lightbox.add_child(img)

    # then, the link to our larger image
    a = create_link_node("lightbox", img["src"])
    img.add_next_sibling(a)

    if upload && Discourse.store.internal?
      a["data-download-href"] = Discourse.store.download_url(upload)
    end

    a.add_child(img)

    # replace the image by its thumbnail
    w, h = img["width"].to_i, img["height"].to_i
    img["src"] = upload.thumbnail(w, h).url if upload && upload.has_thumbnail?(w, h)

    # then, some overlay informations
    meta = create_node("div", "meta")
    img.add_next_sibling(meta)

    filename = get_filename(upload, img["src"])
    informations = "#{original_width}x#{original_height}"
    informations << " #{number_to_human_size(upload.filesize)}" if upload

    a["title"] = CGI.escapeHTML(img["title"] || filename)

    meta.add_child create_span_node("filename", a["title"])
    meta.add_child create_span_node("informations", informations)
    meta.add_child create_span_node("expand")
  end

  def get_filename(upload, src)
    return File.basename(src) unless upload
    return upload.original_filename unless upload.original_filename =~ /^blob(\.png)?$/i
    return I18n.t("upload.pasted_image_filename")
  end

  def create_node(tag_name, klass)
    node = Nokogiri::XML::Node.new(tag_name, @doc)
    node["class"] = klass if klass.present?
    node
  end

  def create_span_node(klass, content = nil)
    span = create_node("span", klass)
    span.content = content if content
    span
  end

  def create_icon_node(klass)
    create_node("i", "fa fa-fw fa-#{klass}")
  end

  def create_link_node(klass, url, external = false)
    a = create_node("a", klass)
    a["href"] = url
    if external
      a["target"] = "_blank"
      a["rel"] = "nofollow noopener"
    end
    a
  end

  def update_post_image
    img = extract_images_for_post.first
    return if img.blank?

    if img["src"].present?
      @post.update_column(:image_url, img["src"][0...255]) # post
      @post.topic.update_column(:image_url, img["src"][0...255]) if @post.is_first_post? # topic
    end
  end

  def post_process_oneboxes
    Oneboxer.apply(@doc) do |url|
      @has_oneboxes = true
      Oneboxer.onebox(url,
        invalidate_oneboxes: !!@opts[:invalidate_oneboxes],
        user_id: @post&.user_id,
        category_id: @post&.topic&.category_id
      )
    end

    oneboxed_images.each do |img|
      next if img["src"].blank?

      src = img["src"].sub(/^https?:/i, "")

      if large_images.include?(src) || broken_images.include?(src)
        img.remove
        next
      end

      upload_id = downloaded_images[src]
      upload = Upload.find(upload_id) if upload_id
      img["src"] = upload.url if upload.present?

      # make sure we grab dimensions for oneboxed images
      # and wrap in a div
      limit_size!(img)

      next if img["class"]&.include?('onebox-avatar')

      parent_class = img.parent && img.parent["class"]
      width = img["width"].to_i
      height = img["height"].to_i

      if parent_class&.include?("onebox-body") && width > 0 && height > 0
        # special instruction for width == height, assume we are dealing with an avatar
        if (img["width"].to_i == img["height"].to_i)
          found = false
          parent = img
          while parent = parent.parent
            if parent["class"] && parent["class"].include?("whitelistedgeneric")
              found = true
              break
            end
          end

          if found
            img["class"] = img["class"].to_s + " onebox-avatar"
            next
          end
        end

        if width < 64 && height < 64
          img["class"] = img["class"].to_s + " onebox-full-image"
        else
          img.delete('width')
          img.delete('height')
          new_parent = img.add_next_sibling("<div class='aspect-image' style='--aspect-ratio:#{width}/#{height};'/>")
          new_parent.first.add_child(img)
        end
      elsif (parent_class&.include?("instagram-images") || parent_class&.include?("tweet-images")) && width > 0 && height > 0
        img.remove_attribute("width")
        img.remove_attribute("height")
        img.parent["class"] = "aspect-image-full-size"
        img.parent["style"] = "--aspect-ratio:#{width}/#{height};"
      end
    end

    if @cooking_options[:omit_nofollow] || !SiteSetting.add_rel_nofollow_to_user_content
      @doc.css(".onebox-body a, .onebox a").each { |a| a.remove_attribute("rel") }
    end
  end

  def optimize_urls
    # attachments can't be on the CDN when either setting is enabled
    if SiteSetting.login_required || SiteSetting.prevent_anons_from_downloading_files
      @doc.css("a.attachment[href]").each do |a|
        href = a["href"].to_s
        a["href"] = UrlHelper.schemaless UrlHelper.absolute_without_cdn(href) if UrlHelper.is_local(href)
      end
    end

    use_s3_cdn = SiteSetting.Upload.enable_s3_uploads && SiteSetting.Upload.s3_cdn_url.present?

    %w{href data-download-href}.each do |selector|
      @doc.css("a[#{selector}]").each do |a|
        href = a[selector].to_s
        a[selector] = UrlHelper.schemaless UrlHelper.absolute(href) if UrlHelper.is_local(href)
        a[selector] = Discourse.store.cdn_url(a[selector]) if use_s3_cdn
      end
    end

    @doc.css("img[src]").each do |img|
      src = img["src"].to_s
      img["src"] = UrlHelper.schemaless UrlHelper.absolute(src) if UrlHelper.is_local(src)
      img["src"] = Discourse.store.cdn_url(img["src"]) if use_s3_cdn
    end
  end

  def enforce_nofollow
    if !@cooking_options[:omit_nofollow] && SiteSetting.add_rel_nofollow_to_user_content
      PrettyText.add_rel_nofollow_to_user_content(@doc)
    end
  end

  def pull_hotlinked_images(bypass_bump = false)
    # is the job enabled?
    return unless SiteSetting.download_remote_images_to_local?
    # have we enough disk space?
    return if disable_if_low_on_disk_space
    # don't download remote images for posts that are more than n days old
    return unless @post.created_at > (Date.today - SiteSetting.download_remote_images_max_days_old)
    # we only want to run the job whenever it's changed by a user
    return if @post.last_editor_id && @post.last_editor_id <= 0
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
    staff_action_logger.log_site_setting_change("download_remote_images_to_local", true, false, details: reason)

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

  private

  def is_svg?(img)
    path =
      begin
        URI(img["src"]).path
      rescue URI::InvalidURIError, URI::InvalidComponentError
        nil
      end

    File.extname(path) == '.svg' if path
  end

end
