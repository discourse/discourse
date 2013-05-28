module PostAnalyser


  def raw_mentions
    return [] if raw.blank?

    # We don't count mentions in quotes
    return @raw_mentions if @raw_mentions.present?
    raw_stripped = raw.gsub(/\[quote=(.*)\]([^\[]*?)\[\/quote\]/im, '')

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
    return [] unless raw.present?

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
