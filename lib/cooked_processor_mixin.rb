# frozen_string_literal: true

module CookedProcessorMixin
  GIF_SOURCES_REGEXP = %r{(giphy|tenor)\.com/}
  LIGHTBOX_WRAPPER_CSS_CLASS = "lightbox-wrapper"
  MIN_LIGHTBOX_WIDTH = 100
  MIN_LIGHTBOX_HEIGHT = 100

  def post_process_oneboxes
    limit = SiteSetting.max_oneboxes_per_post - @doc.css("aside.onebox, a.inline-onebox").size
    oneboxes = {}
    inlineOneboxes = {}

    Oneboxer.apply(@doc, extra_paths: [".inline-onebox-loading"]) do |url, element|
      is_onebox = element["class"] == Oneboxer::ONEBOX_CSS_CLASS
      map = is_onebox ? oneboxes : inlineOneboxes
      skip_onebox = limit <= 0 && !map[url]

      if skip_onebox
        if is_onebox
          element.remove_class("onebox")
        else
          remove_inline_onebox_loading_class(element)
        end

        next
      end

      limit -= 1
      map[url] = true

      if is_onebox
        onebox =
          Oneboxer.onebox(
            url,
            invalidate_oneboxes: !!@opts[:invalidate_oneboxes],
            user_id: @model&.user_id,
            category_id: @category_id,
          )

        @has_oneboxes = true if onebox.present?
        onebox
      else
        process_inline_onebox(element)
        false
      end
    end

    PrettyText.sanitize_hotlinked_media(@doc)

    oneboxed_images.each do |img|
      next if img["src"].blank?

      parent = img.parent

      if respond_to?(:process_hotlinked_image, true)
        still_an_image = process_hotlinked_image(img)
        next if !still_an_image
      end

      # make sure we grab dimensions for oneboxed images
      # and wrap in a div
      limit_size!(img)

      next if img["class"]&.include?("onebox-avatar")

      parent = parent&.parent if parent&.name == "a"
      parent_class = parent && parent["class"]
      width = img["width"].to_i
      height = img["height"].to_i

      if parent_class&.include?("onebox-body") && width > 0 && height > 0
        # special instruction for width == height, assume we are dealing with an avatar
        if (img["width"].to_i == img["height"].to_i)
          found = false
          parent = img
          while parent = parent.parent
            if parent["class"] && parent["class"].match?(/\b(allowlistedgeneric|discoursetopic)\b/)
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
          img.delete("width")
          img.delete("height")
          new_parent =
            img.add_next_sibling(
              "<div class='aspect-image' style='--aspect-ratio:#{width}/#{height};'/>",
            )
          new_parent.first.add_child(img)
        end
      elsif (
            parent_class&.include?("instagram-images") || parent_class&.include?("tweet-images") ||
              parent_class&.include?("scale-images")
          ) && width > 0 && height > 0
        img.remove_attribute("width")
        img.remove_attribute("height")
        parent["class"] = "aspect-image-full-size"
        parent["style"] = "--aspect-ratio:#{width}/#{height};"
      end
    end

    if @omit_nofollow || !SiteSetting.add_rel_nofollow_to_user_content
      @doc
        .css(".onebox-body a[rel], .onebox a[rel]")
        .each do |a|
          rel_values = a["rel"].split(" ").map(&:downcase)
          rel_values.delete("nofollow")
          rel_values.delete("ugc")
          if rel_values.blank?
            a.remove_attribute("rel")
          else
            a["rel"] = rel_values.join(" ")
          end
        end
    end
  end

  def post_process_images
    extract_images.each do |img|
      still_an_image = process_hotlinked_image(img)
      convert_to_link!(img) if still_an_image
    end
  end

  def extract_images
    # all images with a src attribute
    @doc.css("img[src], img[#{PrettyText::BLOCKED_HOTLINKED_SRC_ATTR}]") -
      # minus data images
      @doc.css("img[src^='data']") -
      # minus emojis
      @doc.css("img.emoji")
  end

  def limit_size!(img)
    # retrieve the size from
    #  1) the width/height attributes
    #  2) the dimension from the preview (image_sizes)
    #  3) the dimension of the original image (HTTP request)
    w, h =
      get_size_from_attributes(img) || get_size_from_image_sizes(img["src"], @opts[:image_sizes]) ||
        get_size(img["src"])

    # limit the size of the thumbnail
    img["width"], img["height"] = ImageSizer.resize(w, h)
  end

  def get_size_from_attributes(img)
    w, h = img["width"].to_i, img["height"].to_i
    return w, h if w > 0 && h > 0
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
    return if image_sizes.blank?
    image_sizes.each do |image_size|
      url, size = image_size[0], image_size[1]
      if url && src && url.include?(src) && size && size["width"].to_i > 0 &&
           size["height"].to_i > 0
        return size["width"], size["height"]
      end
    end
    nil
  end

  def add_to_size_cache(url, w, h)
    @size_cache[url] = [w, h]
  end

  def get_size(url)
    return @size_cache[url] if @size_cache.has_key?(url)

    absolute_url = url
    absolute_url = Discourse.base_url_no_prefix + absolute_url if absolute_url =~ %r{\A/[^/]}

    return unless absolute_url

    # FastImage fails when there's no scheme
    absolute_url = SiteSetting.scheme + ":" + absolute_url if absolute_url.start_with?("//")

    # we can't direct FastImage to our secure-uploads url because it bounces
    # anonymous requests with a 404 error
    if url && Upload.secure_uploads_url?(url)
      absolute_url = Upload.signed_url_from_secure_uploads_url(absolute_url)
    end

    return unless is_valid_image_url?(absolute_url)

    upload = Upload.get_from_url(absolute_url)
    if upload && upload.width && upload.width > 0
      @size_cache[url] = [upload.width, upload.height]
    else
      @size_cache[url] = FastImage.size(absolute_url)
    end
  rescue Zlib::BufError, URI::Error, OpenSSL::SSL::SSLError
    # FastImage.size raises BufError for some gifs, leave it.
  end

  def get_filename(upload, src)
    return File.basename(src) unless upload
    return upload.original_filename unless upload.original_filename =~ /\Ablob(\.png)?\z/i
    I18n.t("upload.pasted_image_filename")
  end

  def is_valid_image_url?(url)
    uri = URI.parse(url)
    %w[http https].include? uri.scheme
  rescue URI::Error
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
    span.add_previous_sibling(create_icon_node("far-image"))
    span.add_next_sibling(
      create_span_node(
        "help",
        I18n.t(
          "upload.placeholders.too_large_humanized",
          max_size:
            ActiveSupport::NumberHelper.number_to_human_size(
              SiteSetting.max_image_size_kb.kilobytes,
            ),
        ),
      ),
    )

    # Only if the image is already linked
    if is_hyperlinked
      parent = placeholder.parent
      parent.add_next_sibling(placeholder)

      if parent.name == "a" && parent["href"].present?
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
    true
  end

  def add_broken_image_placeholder!(img)
    img.name = "span"
    img.set_attribute("class", "broken-image")
    img.set_attribute("title", I18n.t("post.image_placeholder.broken"))
    img << "<svg class=\"fa d-icon d-icon-link-slash svg-icon\" aria-hidden=\"true\"><use href=\"#link-slash\"></use></svg>"
    img.remove_attribute("src")
    img.remove_attribute("width")
    img.remove_attribute("height")
    true
  end

  def add_blocked_hotlinked_image_placeholder!(el)
    el.name = "a"
    el.set_attribute("href", el[PrettyText::BLOCKED_HOTLINKED_SRC_ATTR])
    el.set_attribute("class", "blocked-hotlinked-placeholder")
    el.set_attribute("title", I18n.t("post.image_placeholder.blocked_hotlinked_title"))
    el << "<svg class=\"fa d-icon d-icon-link svg-icon\" aria-hidden=\"true\"><use href=\"#link\"></use></svg>"
    el << "<span class=\"notice\">#{CGI.escapeHTML(I18n.t("post.image_placeholder.blocked_hotlinked"))}</span>"

    true
  end

  def add_blocked_hotlinked_media_placeholder!(el, src)
    placeholder = Nokogiri::XML::Node.new("a", el.document)
    placeholder.name = "a"
    placeholder.set_attribute("href", src)
    placeholder.set_attribute("class", "blocked-hotlinked-placeholder")
    placeholder.set_attribute("title", I18n.t("post.media_placeholder.blocked_hotlinked_title"))
    placeholder << "<svg class=\"fa d-icon d-icon-link svg-icon\" aria-hidden=\"true\"><use href=\"#link\"></use></svg>"
    placeholder << "<span class=\"notice\">#{CGI.escapeHTML(I18n.t("post.media_placeholder.blocked_hotlinked"))}</span>"

    el.replace(placeholder)

    true
  end

  def oneboxed_images
    @doc.css(".onebox-body img, .onebox img, img.onebox")
  end

  def is_a_hyperlink?(img)
    parent = img.parent
    while parent
      return true if parent.name == "a"
      parent = parent.parent if parent.respond_to?(:parent)
    end
    false
  end

  def process_inline_onebox(element)
    inline_onebox =
      InlineOneboxer.lookup(
        element.attributes["href"].value,
        invalidate: !!@opts[:invalidate_oneboxes],
        user_id: @model&.user_id,
        category_id: @category_id,
      )

    if title = inline_onebox&.dig(:title)
      element.children = CGI.escapeHTML(title)
      element.add_class("inline-onebox")
    end

    remove_inline_onebox_loading_class(element)
  end

  def remove_inline_onebox_loading_class(element)
    element.remove_class("inline-onebox-loading")
  end

  def dirty?
    @previous_cooked != html
  end

  def html
    @doc.try(:to_html)
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

  def create_icon_node(klass)
    icon = create_node("svg", "fa d-icon d-icon-#{klass} svg-icon")
    icon.set_attribute("aria-hidden", "true")
    icon << "<use href=\"##{klass}\"></use>"
  end

  def create_node(tag_name, klass)
    node = @doc.document.create_element(tag_name)
    node["class"] = klass if klass.present?
    @doc.add_child(node)
    node
  end

  def create_span_node(klass, content = nil)
    span = create_node("span", klass)
    span.content = content if content
    span
  end

  def each_responsive_ratio
    SiteSetting
      .responsive_post_image_sizes
      .split("|")
      .map(&:to_f)
      .sort
      .each { |r| yield r if r > 1 }
  end

  def is_svg?(img)
    path =
      begin
        URI(img["src"]).path
      rescue URI::Error
        nil
      end

    File.extname(path) == ".svg" if path
  end

  def convert_to_link!(img)
    w, h = img["width"].to_i, img["height"].to_i
    user_width, user_height =
      (w > 0 && h > 0 && [w, h]) || get_size_from_attributes(img) ||
        get_size_from_image_sizes(img["src"], @opts[:image_sizes])

    limit_size!(img)

    src = img["src"]
    return if src.blank? || is_a_hyperlink?(img)

    # SVG images can only use the zoom feature in the new lightbox
    return if is_svg?(img) && !SiteSetting.experimental_lightbox

    upload = Upload.get_from_url(src)

    original_width, original_height = nil

    if (upload.present?)
      original_width = upload.width || 0
      original_height = upload.height || 0
    else
      original_width, original_height = (get_size(src) || [0, 0]).map(&:to_i)
      if original_width == 0 || original_height == 0
        Rails.logger.info "Can't reach '#{src}' to get its dimension."
        return
      end
    end

    if (upload.present? && upload.animated?) || src.match?(GIF_SOURCES_REGEXP)
      img.add_class("animated")
    end

    generate_thumbnail =
      original_width > SiteSetting.max_image_width || original_height > SiteSetting.max_image_height

    user_width, user_height = [original_width, original_height] if user_width.to_i <= 0 &&
      user_height.to_i <= 0
    width, height = user_width, user_height

    crop =
      SiteSetting.min_ratio_to_crop > 0 && width.to_f / height.to_f < SiteSetting.min_ratio_to_crop

    if crop
      width, height = ImageSizer.crop(width, height)
      img["width"], img["height"] = width, height
    else
      width, height = ImageSizer.resize(width, height)
    end

    if upload.present?
      if generate_thumbnail
        upload.create_thumbnail!(width, height, crop: crop)

        each_responsive_ratio do |ratio|
          resized_w = (width * ratio).to_i
          resized_h = (height * ratio).to_i

          if upload.width && resized_w <= upload.width
            upload.create_thumbnail!(resized_w, resized_h, crop: crop)
          end
        end
      end

      return if upload.animated?

      if img.ancestors(".onebox, .onebox-body").blank? && !img.classes.include?("onebox")
        add_lightbox!(img, original_width, original_height, upload, crop)
      end

      optimize_image!(img, upload, cropped: crop) if generate_thumbnail
    end
  end

  def process_hotlinked_image(img)
    onebox = img.ancestors(".onebox, .onebox-body").first

    # Skip hotlinked media processing if @post is not available (e.g., for chat messages)
    return true if @post.nil?

    @hotlinked_map ||= @post.post_hotlinked_media.preload(:upload).index_by(&:url)
    normalized_src =
      PostHotlinkedMedia.normalize_src(img["src"] || img[PrettyText::BLOCKED_HOTLINKED_SRC_ATTR])
    info = @hotlinked_map[normalized_src]

    still_an_image = true

    if info&.too_large?
      if !onebox || onebox.element_children.size == 1
        add_large_image_placeholder!(img)
      else
        img.remove
      end

      still_an_image = false
    elsif info&.download_failed?
      if !onebox || onebox.element_children.size == 1
        add_broken_image_placeholder!(img)
      else
        img.remove
      end

      still_an_image = false
    elsif info&.downloaded? && upload = info&.upload
      img["src"] = UrlHelper.cook_url(upload.url, secure: @should_secure_uploads)
      img["data-dominant-color"] = upload.dominant_color(calculate_if_missing: true).presence
      img.delete(PrettyText::BLOCKED_HOTLINKED_SRC_ATTR)
    end

    still_an_image
  end

  def optimize_image!(img, upload, cropped: false)
    w, h = img["width"].to_i, img["height"].to_i
    onebox = img.ancestors(".onebox, .onebox-body").first

    # note: optimize_urls cooks the src further after this
    thumbnail = upload.thumbnail(w, h)
    if thumbnail && thumbnail.filesize.to_i < upload.filesize
      img["src"] = thumbnail.url

      srcset = +""

      # Skip srcset for onebox images. Because onebox thumbnails by default
      # are fairly small the width/height of the smallest thumbnail is likely larger
      # than what the onebox thumbnail size will be displayed at, so we shouldn't
      # need to upscale for retina devices
      if !onebox
        each_responsive_ratio do |ratio|
          resized_w = (w * ratio).to_i
          resized_h = (h * ratio).to_i

          if !cropped && upload.width && resized_w > upload.width
            cooked_url = UrlHelper.cook_url(upload.url, secure: @should_secure_uploads)
            srcset << ", #{cooked_url} #{ratio.to_s.sub(/\.0\z/, "")}x"
          elsif t = upload.thumbnail(resized_w, resized_h)
            cooked_url = UrlHelper.cook_url(t.url, secure: @should_secure_uploads)
            srcset << ", #{cooked_url} #{ratio.to_s.sub(/\.0\z/, "")}x"
          end

          img[
            "srcset"
          ] = "#{UrlHelper.cook_url(img["src"], secure: @should_secure_uploads)}#{srcset}" if srcset.present?
        end
      end
    else
      img["src"] = upload.url
    end

    if !@disable_dominant_color &&
         (color = upload.dominant_color(calculate_if_missing: true).presence)
      img["data-dominant-color"] = color
    end
  end

  def add_lightbox!(img, original_width, original_height, upload, crop)
    return if original_width < MIN_LIGHTBOX_WIDTH || original_height < MIN_LIGHTBOX_HEIGHT

    # first, create a div to hold our lightbox
    lightbox = create_node("div", LIGHTBOX_WRAPPER_CSS_CLASS)
    img.add_next_sibling(lightbox)
    lightbox.add_child(img)

    # then, the link to our larger image
    src_url = Upload.secure_uploads_url?(img["src"]) ? upload&.url || img["src"] : img["src"]
    src = UrlHelper.cook_url(src_url, secure: @should_secure_uploads)

    a = create_link_node("lightbox", src)
    img.add_next_sibling(a)

    a["data-download-href"] = Discourse.store.download_url(upload) if upload

    a.add_child(img)

    # then, some overlay informations
    meta = create_node("div", "meta")
    img.add_next_sibling(meta)

    filename = get_filename(upload, img["src"])
    informations = +"#{original_width}×#{original_height}"
    informations << " #{upload.human_filesize}" if upload

    a["title"] = img["title"] || img["alt"] || filename

    meta.add_child create_icon_node("far-image")
    meta.add_child create_span_node("filename", a["title"])
    meta.add_child create_span_node("informations", informations)
    meta.add_child create_icon_node("discourse-expand")
  end
end
