require_dependency 'final_destination'

module RetrieveTitle
  CRAWL_TIMEOUT = 1

  def self.crawl(url)
    fetch_title(url)
  rescue Exception
    # If there was a connection error, do nothing
  end

  def self.extract_title(html)
    title = nil
    if doc = Nokogiri::HTML(html)

      title = doc.at('title')&.inner_text

      # A horrible hack - YouTube uses `document.title` to populate the title
      # for some reason. For any other site than YouTube this wouldn't be worth it.
      if title == "YouTube" && html =~ /document\.title *= *"(.*)";/
        title = Regexp.last_match[1].sub(/ - YouTube$/, '')
      end

      if !title && node = doc.at('meta[property="og:title"]')
        title = node['content']
      end
    end

    if title.present?
      title.gsub!(/\n/, ' ')
      title.gsub!(/ +/, ' ')
      title.strip!
      return title
    end
    nil
  end

  private

  def self.max_chunk_size(uri)

    # Amazon and YouTube leave the title until very late. Exceptions are bad
    # but these are large sites.
    return 500 if uri.host =~ /amazon\.(com|ca|co\.uk|es|fr|de|it|com\.au|com\.br|cn|in|co\.jp|com\.mx)$/
    return 300 if uri.host =~ /youtube\.com$/ || uri.host =~ /youtu.be/

    # default is 10k
    10
  end

  # Fetch the beginning of a HTML document at a url
  def self.fetch_title(url)
    fd = FinalDestination.new(url, timeout: CRAWL_TIMEOUT)

    current = nil
    title = nil

    fd.get do |_response, chunk, uri|

      if current
        current << chunk
      else
        current = chunk
      end

      max_size = max_chunk_size(uri) * 1024
      title = extract_title(current)
      throw :done if title || max_size < current.length
    end
    return title
  end
end
