# frozen_string_literal: true

class PostAnalyzer
  def initialize(raw, topic_id)
    @raw = raw
    @topic_id = topic_id
    @onebox_urls = []
    @found_oneboxes = false
  end

  def found_oneboxes?
    @found_oneboxes
  end

  def has_oneboxes?
    return false unless @raw.present?

    cooked_stripped
    found_oneboxes?
  end

  # What we use to cook posts
  def cook(raw, opts = {})
    cook_method = opts[:cook_method]
    return raw if cook_method == Post.cook_methods[:raw_html]

    if cook_method == Post.cook_methods[:email]
      cooked = EmailCook.new(raw).cook(opts)
    else
      cooked = PrettyText.cook(raw, opts)
    end

    limit = SiteSetting.max_oneboxes_per_post
    result =
      Oneboxer.apply(cooked, extra_paths: ".inline-onebox-loading") do |url, element|
        if opts[:invalidate_oneboxes]
          Oneboxer.invalidate(url)
          InlineOneboxer.invalidate(url)
        end
        next if element["class"] != Oneboxer::ONEBOX_CSS_CLASS
        next if limit <= 0
        limit -= 1
        @onebox_urls << url
        onebox = Oneboxer.cached_onebox(url)
        @found_oneboxes = true if onebox.present?
        onebox
      end

    if result.changed?
      PrettyText.sanitize_hotlinked_media(result.doc)
      cooked = result.to_html
    end

    cooked
  end

  # How many images are present in the post
  def embedded_media_count
    return 0 unless @raw.present?

    # TODO - do we need to look for tags other than img, video and audio?
    cooked_stripped
      .css("img", "video", "audio")
      .reject do |t|
        if dom_class = t["class"]
          (Post.allowed_image_classes & dom_class.split).count > 0
        end
      end
      .count
  end

  # How many attachments are present in the post
  def attachment_count
    return 0 unless @raw.present?

    attachments =
      cooked_stripped.css("a.attachment[href^=\"#{Discourse.store.absolute_base_url}\"]")
    attachments +=
      cooked_stripped.css(
        "a.attachment[href^=\"#{Discourse.store.relative_base_url}\"]",
      ) if Discourse.store.internal?
    attachments.count
  end

  def raw_mentions
    return [] if @raw.blank?
    return @raw_mentions if @raw_mentions.present?
    @raw_mentions = PrettyText.extract_mentions(cooked_stripped)
  end

  # from rack ... compat with ruby 2.2
  def self.parse_uri_rfc2396(uri)
    @parser ||= defined?(URI::RFC2396_Parser) ? URI::RFC2396_Parser.new : URI
    @parser.parse(uri)
  end

  # Count how many hosts are linked in the post
  def linked_hosts
    all_links = raw_links + @onebox_urls

    return {} if all_links.blank?
    return @linked_hosts if @linked_hosts.present?

    @linked_hosts = {}

    all_links.each do |u|
      begin
        uri = self.class.parse_uri_rfc2396(u)
        host = uri.host
        @linked_hosts[host] ||= 1 unless host.nil?
      rescue URI::Error
        # An invalid URI does not count as a host
        next
      end
    end

    @linked_hosts
  end

  # Returns an array of all links in a post excluding mentions
  def raw_links
    return [] unless @raw.present?
    return @raw_links if @raw_links.present?

    @raw_links = []
    cooked_stripped
      .css("a")
      .each do |l|
        # Don't include @mentions in the link count
        next if link_is_a_mention?(l)
        # Don't include heading anchor in the link count
        next if link_is_an_anchor?(l)
        # Don't include hashtags in the link count
        next if link_is_a_hashtag?(l)
        @raw_links << l["href"].to_s
      end

    @raw_links
  end

  # How many links are present in the post
  def link_count
    raw_links.size + @onebox_urls.size
  end

  def cooked_stripped
    @cooked_stripped ||=
      begin
        doc = Nokogiri::HTML5.fragment(cook(@raw, topic_id: @topic_id))
        doc.css(
          "pre .mention, aside.quote > .title, aside.quote .mention, aside.quote .mention-group, .onebox, .elided",
        ).remove
        doc
      end
  end

  private

  def link_is_a_mention?(l)
    href = l["href"].to_s
    l["class"].to_s["mention"] &&
      (
        href.start_with?("#{Discourse.base_path}/u/") ||
          href.start_with?("#{Discourse.base_path}/users/")
      )
  end

  def link_is_an_anchor?(l)
    l["class"].to_s["anchor"] && l["href"].to_s.start_with?("#")
  end

  def link_is_a_hashtag?(l)
    href = l["href"].to_s
    l["class"].to_s["hashtag"] &&
      (
        href.start_with?("#{Discourse.base_path}/c/") ||
          href.start_with?("#{Discourse.base_path}/tag/")
      )
  end
end
