# frozen_string_literal: true

# Post processing that we can do after a post has already been cooked.
# For example, inserting the onebox content, or image sizes/thumbnails.

class CookedPostProcessor
  include CookedProcessorMixin

  LIGHTBOX_WRAPPER_CSS_CLASS = "lightbox-wrapper"
  LOADING_SIZE = 10
  LOADING_COLORS = 32
  GIF_SOURCES_REGEXP = /(giphy|tenor)\.com\//

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
    @with_secure_media = @post.with_secure_media?
    @category_id = @post&.topic&.category_id

    cooked = post.cook(post.raw, @cooking_options)
    @doc = Loofah.fragment(cooked)
    @has_oneboxes = post.post_analyzer.found_oneboxes?
    @size_cache = {}

    @disable_loading_image = !!opts[:disable_loading_image]
    @omit_nofollow = post.omit_nofollow?
  end

  def post_process(new_post: false)
    DistributedMutex.synchronize("post_process_#{@post.id}", validity: 10.minutes) do
      DiscourseEvent.trigger(:before_post_process_cooked, @doc, @post)
      remove_full_quote_on_direct_reply if new_post
      post_process_oneboxes
      post_process_images
      post_process_quotes
      optimize_urls
      remove_user_ids
      update_post_image
      enforce_nofollow
      pull_hotlinked_images
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
    BadgeGranter.grant(Badge.find(Badge::FirstOnebox), @post.user, post_id: @post.id) if @has_oneboxes
    BadgeGranter.grant(Badge.find(Badge::FirstReplyByEmail), @post.user, post_id: @post.id) if @post.is_reply_by_email?
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

  def remove_full_quote_on_direct_reply
    return if !SiteSetting.remove_full_quote
    return if @post.post_number == 1
    return if @doc.xpath("aside[contains(@class, 'quote')]").size != 1

    previous = Post
      .where("post_number < ? AND topic_id = ? AND post_type = ? AND NOT hidden", @post.post_number, @post.topic_id, Post.types[:regular])
      .order("post_number DESC")
      .limit(1)
      .pluck(:cooked)
      .first

    return if previous.blank?

    previous_text = Nokogiri::HTML5::fragment(previous).text.strip
    quoted_text = @doc.css("aside.quote:first-child blockquote").first&.text&.strip || ""

    return if previous_text.gsub(/(\s){2,}/, '\1') != quoted_text.gsub(/(\s){2,}/, '\1')

    quote_regexp = /\A\s*\[quote.+\[\/quote\]/im
    quoteless_raw = @post.raw.sub(quote_regexp, "").strip

    return if @post.raw.strip == quoteless_raw

    PostRevisor.new(@post).revise!(
      Discourse.system_user,
      {
        raw: quoteless_raw,
        edit_reason: I18n.t(:removed_direct_reply_full_quotes)
      },
      skip_validations: true,
      bypass_bump: true
    )
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

  def extract_images
    # all images with a src attribute
    @doc.css("img[src]") -
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
    @doc.css("img.onebox-avatar") -
    @doc.css("img.onebox-avatar-inline") -
    # minus github onebox profile images
    @doc.css(".onebox.githubfolder img")
  end

  def large_images
    @large_images ||= @post&.custom_fields[Post::LARGE_IMAGES].presence || []
  end

  def broken_images
    @broken_images ||= @post&.custom_fields[Post::BROKEN_IMAGES].presence || []
  end

  def downloaded_images
    @downloaded_images ||= @post&.downloaded_images || []
  end

  def convert_to_link!(img)
    w, h = img["width"].to_i, img["height"].to_i
    user_width, user_height = (w > 0 && h > 0 && [w, h]) ||
                              get_size_from_attributes(img) ||
                              get_size_from_image_sizes(img["src"], @opts[:image_sizes])

    limit_size!(img)

    src = img["src"]
    return if src.blank? || is_a_hyperlink?(img) || is_svg?(img)

    original_width, original_height = (get_size(src) || [0, 0]).map(&:to_i)
    if original_width == 0 || original_height == 0
      Rails.logger.info "Can't reach '#{src}' to get its dimension."
      return
    end

    upload = Upload.get_from_url(src)

    if (upload.present? && upload.animated?) || src.match?(GIF_SOURCES_REGEXP)
      img.add_class("animated")
    end

    return if original_width <= SiteSetting.max_image_width && original_height <= SiteSetting.max_image_height

    user_width, user_height = [original_width, original_height] if user_width.to_i <= 0 && user_height.to_i <= 0
    width, height = user_width, user_height

    crop = SiteSetting.min_ratio_to_crop > 0 && width.to_f / height.to_f < SiteSetting.min_ratio_to_crop

    if crop
      width, height = ImageSizer.crop(width, height)
      img["width"], img["height"] = width, height
    else
      width, height = ImageSizer.resize(width, height)
    end

    if upload.present?
      upload.create_thumbnail!(width, height, crop: crop)

      each_responsive_ratio do |ratio|
        resized_w = (width * ratio).to_i
        resized_h = (height * ratio).to_i

        if upload.width && resized_w <= upload.width
          upload.create_thumbnail!(resized_w, resized_h, crop: crop)
        end
      end

      unless @disable_loading_image
        upload.create_thumbnail!(LOADING_SIZE, LOADING_SIZE, format: 'png', colors: LOADING_COLORS)
      end

      return if upload.animated?

      if img.ancestors('.onebox, .onebox-body, .quote').blank? && !img.classes.include?("onebox")
        add_lightbox!(img, original_width, original_height, upload, cropped: crop)
      end

      optimize_image!(img, upload, cropped: crop)
    end
  end

  def loading_image(upload)
    upload.thumbnail(LOADING_SIZE, LOADING_SIZE)
  end

  def each_responsive_ratio
    SiteSetting
      .responsive_post_image_sizes
      .split('|')
      .map(&:to_f)
      .sort
      .each { |r| yield r if r > 1 }
  end

  def optimize_image!(img, upload, cropped: false)
    w, h = img["width"].to_i, img["height"].to_i

    # note: optimize_urls cooks the src and data-small-upload further after this
    thumbnail = upload.thumbnail(w, h)
    if thumbnail && thumbnail.filesize.to_i < upload.filesize
      img["src"] = thumbnail.url

      srcset = +""

      each_responsive_ratio do |ratio|
        resized_w = (w * ratio).to_i
        resized_h = (h * ratio).to_i

        if !cropped && upload.width && resized_w > upload.width
          cooked_url = UrlHelper.cook_url(upload.url, secure: @post.with_secure_media?)
          srcset << ", #{cooked_url} #{ratio.to_s.sub(/\.0$/, "")}x"
        elsif t = upload.thumbnail(resized_w, resized_h)
          cooked_url = UrlHelper.cook_url(t.url, secure: @post.with_secure_media?)
          srcset << ", #{cooked_url} #{ratio.to_s.sub(/\.0$/, "")}x"
        end

        img["srcset"] = "#{UrlHelper.cook_url(img["src"], secure: @post.with_secure_media?)}#{srcset}" if srcset.present?
      end
    else
      img["src"] = upload.url
    end

    if small_upload = loading_image(upload)
      img["data-small-upload"] = small_upload.url
    end
  end

  def add_lightbox!(img, original_width, original_height, upload, cropped: false)
    # first, create a div to hold our lightbox
    lightbox = create_node("div", LIGHTBOX_WRAPPER_CSS_CLASS)
    img.add_next_sibling(lightbox)
    lightbox.add_child(img)

    # then, the link to our larger image
    src = UrlHelper.cook_url(img["src"], secure: @post.with_secure_media?)
    a = create_link_node("lightbox", src)
    img.add_next_sibling(a)

    if upload
      a["data-download-href"] = Discourse.store.download_url(upload)
    end

    a.add_child(img)

    # then, some overlay informations
    meta = create_node("div", "meta")
    img.add_next_sibling(meta)

    filename = get_filename(upload, img["src"])
    informations = +"#{original_width}×#{original_height}"
    informations << " #{upload.human_filesize}" if upload

    a["title"] = CGI.escapeHTML(img["title"] || img["alt"] || filename)

    meta.add_child create_icon_node("far-image")
    meta.add_child create_span_node("filename", a["title"])
    meta.add_child create_span_node("informations", informations)
    meta.add_child create_icon_node("discourse-expand")
  end

  def get_filename(upload, src)
    return File.basename(src) unless upload
    return upload.original_filename unless upload.original_filename =~ /^blob(\.png)?$/i
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
        extra_sizes = ThemeModifierHelper.new(theme_ids: Theme.user_selectable.pluck(:id)).topic_thumbnail_sizes
        @post.topic.generate_thumbnails!(extra_sizes: extra_sizes)
      end
    else
      @post.update_column(:image_upload_id, nil) if @post.image_upload_id
      @post.topic.update_column(:image_upload_id, nil) if @post.topic.image_upload_id && @post.is_first_post?
      nil
    end
  end

  def optimize_urls
    %w{href data-download-href}.each do |selector|
      @doc.css("a[#{selector}]").each do |a|
        a[selector] = UrlHelper.cook_url(a[selector].to_s)
      end
    end

    %w{src data-small-upload}.each do |selector|
      @doc.css("img[#{selector}]").each do |img|
        img[selector] = UrlHelper.cook_url(img[selector].to_s, secure: @post.with_secure_media?)
      end
    end
  end

  def remove_user_ids
    @doc.css("a[href]").each do |a|
      uri = begin
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

  def pull_hotlinked_images
    return if @opts[:skip_pull_hotlinked_images]
    # have we enough disk space?
    disable_if_low_on_disk_space # But still enqueue the job
    # make sure no other job is scheduled
    Jobs.cancel_scheduled_job(:pull_hotlinked_images, post_id: @post.id)
    # schedule the job
    delay = SiteSetting.editing_grace_period + 1
    Jobs.enqueue_in(delay.seconds.to_i, :pull_hotlinked_images, post_id: @post.id)
  end

  def disable_if_low_on_disk_space
    return if Discourse.store.external?
    return if !SiteSetting.download_remote_images_to_local
    return if available_disk_space >= SiteSetting.download_remote_images_threshold

    SiteSetting.download_remote_images_to_local = false

    # log the site setting change
    reason = I18n.t("disable_remote_images_download_reason")
    staff_action_logger = StaffActionLogger.new(Discourse.system_user)
    staff_action_logger.log_site_setting_change("download_remote_images_to_local", true, false, details: reason)

    # also send a private message to the site contact user notify_about_low_disk_space
    notify_about_low_disk_space
  end

  def notify_about_low_disk_space
    SystemMessage.create_from_system_user(Discourse.site_contact_user, :download_remote_images_disabled)
  end

  def available_disk_space
    100 - DiskSpace.percent_free("#{Rails.root}/public/uploads")
  end

  private

  def post_process_images
    extract_images.each do |img|
      convert_to_link!(img) unless add_image_placeholder!(img)
    end
  end

  def is_svg?(img)
    path =
      begin
        URI(img["src"]).path
      rescue URI::Error
        nil
      end

    File.extname(path) == '.svg' if path
  end
end
