# frozen_string_literal: true

# Post processing that we can do after a post has already been cooked.
# For example, inserting the onebox content, or image sizes/thumbnails.

class CookedPostProcessor
  include CookedProcessorMixin

  LIGHTBOX_WRAPPER_CSS_CLASS = "lightbox-wrapper"
  GIF_SOURCES_REGEXP = %r{(giphy|tenor)\.com/}
  MIN_LIGHTBOX_WIDTH = 100
  MIN_LIGHTBOX_HEIGHT = 100

  attr_reader :cooking_options, :doc

  def initialize(post, opts = {})
    @dirty = false
    @opts = opts
    @post = post
    @model = post
    @previous_cooked = (@post.cooked || "").dup
    # NOTE: we re-cook the post here in order to prevent timing issues with edits
    # cf. https://meta.discourse.org/t/edit-of-rebaked-post-doesnt-show-in-html-only-in-raw/33815/6
    @cooking_options = post.cooking_options || opts[:cooking_options] || {}
    @cooking_options[:topic_id] = post.topic_id
    @cooking_options = @cooking_options.symbolize_keys
    @should_secure_uploads = @post.should_secure_uploads?
    @category_id = @post&.topic&.category_id

    cooked = post.cook(post.raw, @cooking_options)
    @doc = Loofah.html5_fragment(cooked)
    @has_oneboxes = post.post_analyzer.found_oneboxes?
    @size_cache = {}

    @disable_dominant_color = !!opts[:disable_dominant_color]
    @omit_nofollow = post.omit_nofollow?
  end

  def post_process(new_post: false)
    DistributedMutex.synchronize("post_process_#{@post.id}", validity: 10.minutes) do
      DiscourseEvent.trigger(:before_post_process_cooked, @doc, @post)
      update_uploads_secure_status
      remove_full_quote_on_direct_reply if new_post
      post_process_oneboxes
      post_process_images
      add_blocked_hotlinked_media_placeholders
      post_process_quotes
      optimize_urls
      remove_user_ids
      update_post_image
      enforce_nofollow
      grant_badges
      @post.link_post_uploads(fragments: @doc)
      DiscourseEvent.trigger(:post_process_cooked, @doc, @post)
      nil
    end
  end

  def has_emoji?
    (@doc.css("img.emoji") - @doc.css(".quote img")).size > 0
  end

  def grant_badges
    return if @post.user.blank? || !Guardian.new.can_see?(@post)

    BadgeGranter.grant(Badge.find(Badge::FirstEmoji), @post.user, post_id: @post.id) if has_emoji?
    if @has_oneboxes
      BadgeGranter.grant(Badge.find(Badge::FirstOnebox), @post.user, post_id: @post.id)
    end
    if @post.is_reply_by_email?
      BadgeGranter.grant(Badge.find(Badge::FirstReplyByEmail), @post.user, post_id: @post.id)
    end
  end

  def post_process_quotes
    @doc
      .css("aside.quote")
      .each do |q|
        post_number = q["data-post"]
        topic_id = q["data-topic"]
        if topic_id && post_number
          comparer = QuoteComparer.new(topic_id.to_i, post_number.to_i, q.css("blockquote").text)

          q["class"] = ((q["class"] || "") + " quote-post-not-found").strip if comparer.missing?
          q["class"] = ((q["class"] || "") + " quote-modified").strip if comparer.modified?
        end
      end
  end

  def update_uploads_secure_status
    @post.update_uploads_secure_status(source: "post processor")
  end

  def remove_full_quote_on_direct_reply
    return if !SiteSetting.remove_full_quote
    return if @post.post_number == 1
    return if @doc.xpath("aside[contains(@class, 'quote')]").size != 1

    previous =
      Post
        .where(
          "post_number < ? AND topic_id = ? AND post_type = ? AND NOT hidden",
          @post.post_number,
          @post.topic_id,
          Post.types[:regular],
        )
        .order("post_number DESC")
        .limit(1)
        .pluck(:cooked)
        .first

    return if previous.blank?

    previous_text = Nokogiri::HTML5.fragment(previous).text.strip
    quoted_text = @doc.css("aside.quote:first-child blockquote").first&.text&.strip || ""

    return if previous_text.gsub(/(\s){2,}/, '\1') != quoted_text.gsub(/(\s){2,}/, '\1')

    quote_regexp = %r{\A\s*\[quote.+\[/quote\]}im
    quoteless_raw = @post.raw.sub(quote_regexp, "").strip

    return if @post.raw.strip == quoteless_raw

    PostRevisor.new(@post).revise!(
      Discourse.system_user,
      { raw: quoteless_raw, edit_reason: I18n.t(:removed_direct_reply_full_quotes) },
      skip_validations: true,
      bypass_bump: true,
    )
  end

  def extract_images
    # all images with a src attribute
    @doc.css("img[src], img[#{PrettyText::BLOCKED_HOTLINKED_SRC_ATTR}]") -
      # minus data images
      @doc.css("img[src^='data']") -
      # minus emojis
      @doc.css("img.emoji")
  end

  def extract_images_for_post
    # all images with a src attribute
    @doc.css("img[src]") -
      # minus emojis
      @doc.css("img.emoji") -
      # minus images inside quotes
      @doc.css(".quote img") -
      # minus onebox site icons
      @doc.css("img.site-icon") -
      # minus onebox avatars
      @doc.css("img.onebox-avatar") - @doc.css("img.onebox-avatar-inline") -
      # minus github onebox profile images
      @doc.css(".onebox.githubfolder img")
  end

  def convert_to_link!(img)
    w, h = img["width"].to_i, img["height"].to_i
    user_width, user_height =
      (w > 0 && h > 0 && [w, h]) || get_size_from_attributes(img) ||
        get_size_from_image_sizes(img["src"], @opts[:image_sizes])

    limit_size!(img)

    src = img["src"]
    return if src.blank? || is_a_hyperlink?(img) || is_svg?(img)

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

    skip_thumbnail =
      original_width <= SiteSetting.max_image_width &&
        original_height <= SiteSetting.max_image_height

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
      unless skip_thumbnail
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
        add_lightbox!(img, original_width, original_height, upload)
      end

      optimize_image!(img, upload, cropped: crop) unless skip_thumbnail
    end
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

  def add_lightbox!(img, original_width, original_height, upload)
    return if original_width < MIN_LIGHTBOX_WIDTH || original_height < MIN_LIGHTBOX_HEIGHT

    # first, create a div to hold our lightbox
    lightbox = create_node("div", LIGHTBOX_WRAPPER_CSS_CLASS)
    img.add_next_sibling(lightbox)
    lightbox.add_child(img)

    # then, the link to our larger image
    src_url = Upload.secure_uploads_url?(img["src"]) ? upload&.url : img["src"]
    src = UrlHelper.cook_url(src_url || img["src"], secure: @should_secure_uploads)
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

  def get_filename(upload, src)
    return File.basename(src) unless upload
    return upload.original_filename unless upload.original_filename =~ /\Ablob(\.png)?\z/i
    I18n.t("upload.pasted_image_filename")
  end

  def update_post_image
    upload = nil
    images = extract_images_for_post

    @post.each_upload_url(fragments: images.css("[data-thumbnail]")) do |src, path, sha1|
      upload = Upload.find_by(sha1: sha1)
      break if upload
    end

    if upload.nil? # No specified thumbnail. Use any image:
      @post.each_upload_url(fragments: images.css(":not([data-thumbnail])")) do |src, path, sha1|
        upload = Upload.find_by(sha1: sha1)
        break if upload
      end
    end

    if upload.present?
      @post.update_column(:image_upload_id, upload.id) # post
      if @post.is_first_post? # topic
        @post.topic.update_column(:image_upload_id, upload.id)
        extra_sizes =
          ThemeModifierHelper.new(theme_ids: Theme.user_selectable.pluck(:id)).topic_thumbnail_sizes
        @post.topic.generate_thumbnails!(extra_sizes: extra_sizes)
      end
    else
      @post.update_column(:image_upload_id, nil) if @post.image_upload_id
      if @post.topic.image_upload_id && @post.is_first_post?
        @post.topic.update_column(:image_upload_id, nil)
      end
      nil
    end
  end

  def optimize_urls
    %w[href data-download-href].each do |selector|
      @doc.css("a[#{selector}]").each { |a| a[selector] = UrlHelper.cook_url(a[selector].to_s) }
    end

    %w[src].each do |selector|
      @doc
        .css("img[#{selector}]")
        .each do |img|
          custom_emoji = img["class"]&.include?("emoji-custom") && Emoji.custom?(img["title"])
          img[selector] = UrlHelper.cook_url(
            img[selector].to_s,
            secure: @should_secure_uploads && !custom_emoji,
          )
        end
    end
  end

  def remove_user_ids
    @doc
      .css("a[href]")
      .each do |a|
        uri =
          begin
            URI(a["href"])
          rescue URI::Error
            next
          end
        next if uri.hostname != Discourse.current_hostname

        query = Rack::Utils.parse_nested_query(uri.query)
        next if !query.delete("u")

        uri.query = query.map { |k, v| "#{k}=#{v}" }.join("&").presence
        a["href"] = uri.to_s
      end
  end

  def enforce_nofollow
    add_nofollow = !@omit_nofollow && SiteSetting.add_rel_nofollow_to_user_content
    PrettyText.add_rel_attributes_to_user_content(@doc, add_nofollow)
  end

  private

  def post_process_images
    extract_images.each do |img|
      still_an_image = process_hotlinked_image(img)
      convert_to_link!(img) if still_an_image
    end
  end

  def process_hotlinked_image(img)
    onebox = img.ancestors(".onebox, .onebox-body").first

    @hotlinked_map ||= @post.post_hotlinked_media.preload(:upload).map { |r| [r.url, r] }.to_h
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

  def add_blocked_hotlinked_media_placeholders
    @doc
      .css(
        [
          "[#{PrettyText::BLOCKED_HOTLINKED_SRC_ATTR}]",
          "[#{PrettyText::BLOCKED_HOTLINKED_SRCSET_ATTR}]",
        ].join(","),
      )
      .each do |el|
        src =
          el[PrettyText::BLOCKED_HOTLINKED_SRC_ATTR] ||
            el[PrettyText::BLOCKED_HOTLINKED_SRCSET_ATTR]&.split(",")&.first&.split(" ")&.first

        if el.name == "img"
          add_blocked_hotlinked_image_placeholder!(el)
          next
        end

        el = el.parent if %w[video audio].include?(el.parent.name)

        el = el.parent if el.parent.classes.include?("video-container")

        add_blocked_hotlinked_media_placeholder!(el, src)
      end
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
end
