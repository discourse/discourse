# frozen_string_literal: true

module CookedProcessorMixin

  def post_process_oneboxes
    limit = SiteSetting.max_oneboxes_per_post
    oneboxes = {}
    inlineOneboxes = {}

    Oneboxer.apply(@doc, extra_paths: [".inline-onebox-loading"]) do |url, element|
      is_onebox = element["class"] == Oneboxer::ONEBOX_CSS_CLASS
      map = is_onebox ? oneboxes : inlineOneboxes
      skip_onebox = limit <= 0 && !map[url]

      if skip_onebox
        if is_onebox
          element.remove_class('onebox')
        else
          remove_inline_onebox_loading_class(element)
        end

        next
      end

      limit -= 1
      map[url] = true

      if is_onebox
        onebox = Oneboxer.onebox(url,
          invalidate_oneboxes: !!@opts[:invalidate_oneboxes],
          user_id: @model&.user_id,
          category_id: @category_id
        )

        @has_oneboxes = true if onebox.present?
        onebox
      else
        process_inline_onebox(element)
        false
      end
    end

    oneboxed_images.each do |img|
      next if img["src"].blank?

      src = img["src"].sub(/^https?:/i, "")
      parent = img.parent
      img_classes = (img["class"] || "").split(" ")
      link_classes = ((parent&.name == "a" && parent["class"]) || "").split(" ")

      if img_classes.include?("onebox") || link_classes.include?("onebox")
        next if add_image_placeholder!(img)
      elsif large_images.include?(src) || broken_images.include?(src)
        img.remove
        next
      end

      upload_id = downloaded_images[src]
      upload = Upload.find_by_id(upload_id) if upload_id

      if upload.present?
        img["src"] = UrlHelper.cook_url(upload.url, secure: @with_secure_media)
      end

      # make sure we grab dimensions for oneboxed images
      # and wrap in a div
      limit_size!(img)

      next if img["class"]&.include?('onebox-avatar')

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
            if parent["class"] && parent["class"].include?("allowlistedgeneric")
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
      elsif (parent_class&.include?("instagram-images") || parent_class&.include?("tweet-images") || parent_class&.include?("scale-images")) && width > 0 && height > 0
        img.remove_attribute("width")
        img.remove_attribute("height")
        parent["class"] = "aspect-image-full-size"
        parent["style"] = "--aspect-ratio:#{width}/#{height};"
      end
    end

    if @omit_nofollow || !SiteSetting.add_rel_nofollow_to_user_content
      @doc.css(".onebox-body a[rel], .onebox a[rel]").each do |a|
        rel_values = a['rel'].split(' ').map(&:downcase)
        rel_values.delete('nofollow')
        rel_values.delete('ugc')
        if rel_values.blank?
          a.remove_attribute("rel")
        else
          a["rel"] = rel_values.join(' ')
        end
      end
    end
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
    nil
  end

  def add_to_size_cache(url, w, h)
    @size_cache[url] = [w, h]
  end

  def get_size(url)
    return @size_cache[url] if @size_cache.has_key?(url)

    absolute_url = url
    absolute_url = Discourse.base_url_no_prefix + absolute_url if absolute_url =~ /^\/[^\/]/

    return unless absolute_url

    # FastImage fails when there's no scheme
    absolute_url = SiteSetting.scheme + ":" + absolute_url if absolute_url.start_with?("//")

    # we can't direct FastImage to our secure-media-uploads url because it bounces
    # anonymous requests with a 404 error
    if url && Upload.secure_media_url?(url)
      absolute_url = Upload.signed_url_from_secure_media_url(absolute_url)
    end

    return unless is_valid_image_url?(absolute_url)

    @size_cache[url] = FastImage.size(absolute_url)
  rescue Zlib::BufError, URI::Error, OpenSSL::SSL::SSLError
    # FastImage.size raises BufError for some gifs, leave it.
  end

  def is_valid_image_url?(url)
    uri = URI.parse(url)
    %w(http https).include? uri.scheme
  rescue URI::Error
  end

  def add_image_placeholder!(img)
    src = img["src"].sub(/^https?:/i, "")

    if large_images.include?(src)
      return add_large_image_placeholder!(img)
    elsif broken_images.include?(src)
      return add_broken_image_placeholder!(img)
    end

    false
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
          max_size: ActiveSupport::NumberHelper.number_to_human_size(SiteSetting.max_image_size_kb.kilobytes)
        )
      )
    )

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
    true
  end

  def add_broken_image_placeholder!(img)
    img.name = "span"
    img.set_attribute("class", "broken-image")
    img.set_attribute("title", I18n.t("post.image_placeholder.broken"))
    img << "<svg class=\"fa d-icon d-icon-unlink svg-icon\" aria-hidden=\"true\"><use href=\"#unlink\"></use></svg>"
    img.remove_attribute("src")
    img.remove_attribute("width")
    img.remove_attribute("height")
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
    inline_onebox = InlineOneboxer.lookup(
      element.attributes["href"].value,
      invalidate: !!@opts[:invalidate_oneboxes],
      user_id: @model&.user_id,
      category_id: @category_id
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
    node = Nokogiri::XML::Node.new(tag_name, @doc)
    node["class"] = klass if klass.present?
    node
  end

  def create_span_node(klass, content = nil)
    span = create_node("span", klass)
    span.content = content if content
    span
  end
end
