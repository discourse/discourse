# frozen_string_literal: true

# Post processing that we can do after a post has already been cooked.
# For example, inserting the onebox content, or image sizes/thumbnails.

class CookedPostProcessor
  include CookedProcessorMixin

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
      post_process_videos
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
        .css("img[#{selector}], video[#{selector}]")
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

  def post_process_videos
    changes_made = false

    begin
      @doc
        .css(".video-placeholder-container")
        .each do |container|
          src = container["data-video-src"]
          next if src.blank?

          # Look for optimized video
          upload = Upload.get_from_url(src)
          if upload && optimized_video = OptimizedVideo.find_by(upload_id: upload.id)
            optimized_url = optimized_video.optimized_upload.url
            # Only update if the URL is different
            if container["data-video-src"] != optimized_url
              container["data-original-video-src"] = container["data-video-src"] unless container[
                "data-original-video-src"
              ]
              container["data-video-src"] = optimized_url
              changes_made = true
            end
            # Ensure we maintain reference to original upload
            @post.link_post_uploads(fragments: @doc)
          end
        end

      # Update the post's cooked content if changes were made
      if changes_made
        new_cooked = @doc.to_html
        @post.cooked = new_cooked
        if !@post.save
          Rails.logger.error("Failed to save post: #{@post.errors.full_messages.join(", ")}")
        end
      end
    rescue => e
      Rails.logger.error("Error in post_process_videos: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise
    end
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
end
