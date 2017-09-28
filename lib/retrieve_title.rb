require_dependency 'final_destination'

module RetrieveTitle
  class ReadEnough < StandardError; end

  def self.crawl(url)
    extract_title(fetch_beginning(url))
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
      return 80 if uri.host =~ /amazon\.(com|ca|co\.uk|es|fr|de|it|com\.au|com\.br|cn|in|co\.jp|com\.mx)$/
      return 300 if uri.host =~ /youtube\.com$/ || uri.host =~ /youtu.be/

      # default is 10k
      10
    end

    # Fetch the beginning of a HTML document at a url
    def self.fetch_beginning(url)
      fd = FinalDestination.new(url)
      uri = fd.resolve
      return "" unless uri

      result = ""
      streamer = lambda do |chunk, _, _|
        result << chunk

        # Using exceptions for flow control is really bad, but there really seems to
        # be no sane way to get a stream to stop reading in Excon (or Net::HTTP for
        # that matter!)
        raise ReadEnough.new if result.size > (max_chunk_size(uri) * 1024)
      end
      Excon.get(uri.to_s, response_block: streamer, read_timeout: 20, headers: fd.request_headers)
      result

    rescue Excon::Errors::SocketError => ex
      return result if ex.socket_error.is_a?(ReadEnough)
      raise
    rescue ReadEnough
      result
    end
end
