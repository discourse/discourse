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

    result = Oneboxer.apply(cooked) do |url|
      @onebox_urls << url
      Oneboxer.invalidate(url) if opts[:invalidate_oneboxes]
      onebox = Oneboxer.cached_onebox(url)
      @found_oneboxes = true if onebox.present?
      onebox
    end

    cooked = result.to_html if result.changed?
    cooked
  end

  # How many images are present in the post
  def image_count
    return 0 unless @raw.present?

    cooked_stripped.css("img").reject do |t|
      if dom_class = t["class"]
        (Post.white_listed_image_classes & dom_class.split).count > 0
      end
    end.count
  end

  # How many attachments are present in the post
  def attachment_count
    return 0 unless @raw.present?

    attachments  = cooked_stripped.css("a.attachment[href^=\"#{Discourse.store.absolute_base_url}\"]")
    attachments += cooked_stripped.css("a.attachment[href^=\"#{Discourse.store.relative_base_url}\"]") if Discourse.store.internal?
    attachments.count
  end

  def raw_mentions
    return [] if @raw.blank?
    return @raw_mentions if @raw_mentions.present?

    raw_mentions = cooked_stripped.css('.mention, .mention-group').map do |e|
      if name = e.inner_text
        name = name[1..-1]
        name = User.normalize_username(name)
        name
      end
    end

    raw_mentions.compact!
    raw_mentions.uniq!
    @raw_mentions = raw_mentions
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
    cooked_stripped.css("a").each do |l|
      # Don't include @mentions in the link count
      next if link_is_a_mention?(l)
      @raw_links << l['href'].to_s
    end

    @raw_links
  end

  # How many links are present in the post
  def link_count
    raw_links.size + @onebox_urls.size
  end

  def cooked_stripped
    @cooked_stripped ||= begin
      doc = Nokogiri::HTML.fragment(cook(@raw, topic_id: @topic_id))
      doc.css("pre .mention, aside.quote > .title, aside.quote .mention, aside.quote .mention-group, .onebox, .elided").remove
      doc
    end
  end

  private

  def link_is_a_mention?(l)
    html_class = l['class']
    return false if html_class.blank?
    href = l['href'].to_s
    html_class.to_s['mention'] && href[/^\/u\//] || href[/^\/users\//]
  end

end
