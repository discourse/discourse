class PostAnalyzer

  attr_accessor :cooked, :raw

  def initialize(raw, topic_id)
    @raw  = raw
    @topic_id = topic_id
  end

  def cooked_document
    @cooked = cook(@raw, topic_id: @topic_id)
    @cooked_document = Nokogiri::HTML.fragment(@cooked)
  end

  # What we use to cook posts
  def cook(*args)
    cooked = PrettyText.cook(*args)

    # If we have any of the oneboxes in the cache, throw them in right away, don't
    # wait for the post processor.
    result = Oneboxer.apply(cooked) do |url, elem|
      Oneboxer.invalidate(url) if args.last[:invalidate_oneboxes]
      Oneboxer.onebox url
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

  def raw_mentions
    return [] if @raw.blank?

    # We don't count mentions in quotes
    return @raw_mentions if @raw_mentions.present?
    raw_stripped = @raw.gsub(/\[quote=(.*)\]([^\[]*?)\[\/quote\]/im, '')

    # Strip pre and code tags
    doc = Nokogiri::HTML.fragment(raw_stripped)
    doc.search("pre").remove
    doc.search("code").remove

    results = doc.to_html.scan(PrettyText.mention_matcher)
    @raw_mentions = results.uniq.map { |un| un.first.downcase.gsub!(/^@/, '') }
  end

  # Count how many hosts are linked in the post
  def linked_hosts
    return {} if raw_links.blank?

    return @linked_hosts if @linked_hosts.present?

    @linked_hosts = {}
    raw_links.each do |u|
      uri = URI.parse(u)
      host = uri.host
      @linked_hosts[host] ||= 1
    end
    @linked_hosts
  end

  # Returns an array of all links in a post excluding mentions
  def raw_links
    return [] unless @raw.present?

    return @raw_links if @raw_links.present?

    # Don't include @mentions in the link count
    @raw_links = []
    cooked_document.search("a[href]").each do |l|
      next if link_is_a_mention?(l)
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

  def link_is_a_mention?(l)
    html_class = l.attributes['class']
    return false if html_class.nil?
    html_class.to_s == 'mention' && l.attributes['href'].to_s =~ /^\/users\//
  end
end
