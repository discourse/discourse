require_dependency 'oneboxer'

class PostAnalyzer

  def initialize(raw, topic_id)
    @raw  = raw
    @topic_id = topic_id
    @found_oneboxes = false
  end

  def found_oneboxes?
    @found_oneboxes
  end

  # What we use to cook posts
  def cook(*args)
    cooked = PrettyText.cook(*args)

    result = Oneboxer.apply(cooked, topic_id: @topic_id) do |url, _|
      @found_oneboxes = true
      Oneboxer.invalidate(url) if args.last[:invalidate_oneboxes]
      Oneboxer.cached_onebox url
    end

    cooked = result.to_html if result.changed?
    cooked
  end

  # How many images are present in the post
  def image_count
    return 0 unless @raw.present?

    cooked_document.search("img").reject do |t|
      dom_class = t["class"]
      if dom_class
        (Post.white_listed_image_classes & dom_class.split(" ")).count > 0
      end
    end.count
  end

  # How many attachments are present in the post
  def attachment_count
    return 0 unless @raw.present?

    attachments = cooked_document.css("a.attachment[href^=\"#{Discourse.store.absolute_base_url}\"]")
    attachments += cooked_document.css("a.attachment[href^=\"#{Discourse.store.relative_base_url}\"]") if Discourse.store.internal?
    attachments.count
  end

  def raw_mentions
    return [] if @raw.blank?
    return @raw_mentions if @raw_mentions.present?

    # strip quotes, code blocks and oneboxes
    cooked_stripped = cooked_document
    cooked_stripped.css("aside.quote").remove
    cooked_stripped.css("pre").remove
    cooked_stripped.css("code").remove
    cooked_stripped.css(".onebox").remove

    raw_mentions = cooked_stripped.css('.mention, .mention-group').map do |e|
       if name = e.inner_text
         name = name[1..-1]
         name.downcase! if name
         name
       end
    end

    raw_mentions.compact!
    raw_mentions.uniq!
    @raw_mention = raw_mentions
  end

  # from rack ... compat with ruby 2.2
  def self.parse_uri_rfc2396(uri)
    @parser ||= defined?(URI::RFC2396_Parser) ? URI::RFC2396_Parser.new : URI
    @parser.parse(uri)
  end

  # Count how many hosts are linked in the post
  def linked_hosts
    return {} if raw_links.blank?
    return @linked_hosts if @linked_hosts.present?

    @linked_hosts = {}

    raw_links.each do |u|
      begin
        uri = self.class.parse_uri_rfc2396(u)
        host = uri.host
        @linked_hosts[host] ||= 1 unless host.nil?
      rescue URI::InvalidURIError
        # An invalid URI does not count as a raw link.
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

    cooked_document.search("a").each do |l|
      # Don't include @mentions in the link count
      next if l.attributes['href'].nil? || link_is_a_mention?(l)
      url = l.attributes['href'].to_s
      @raw_links << url
    end

    @raw_links
  end

  # How many links are present in the post
  def link_count
    raw_links.size
  end

  private

  def cooked_document
    @cooked_document ||= Nokogiri::HTML.fragment(cook(@raw, topic_id: @topic_id))
  end

  def link_is_a_mention?(l)
    html_class = l.attributes['class']
    return false if html_class.nil?
    html_class.to_s == 'mention' && l.attributes['href'].to_s =~ /^\/users\//
  end
end
