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

      if node = doc.at('meta[property="og:title"]')
        title = node['content']
      end

      title ||= doc.at('title')&.inner_text
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
      # Amazon leaves the title until very late. Normally it's a bad idea to make an exception for
      # one host but amazon is a big one.
      return 80 if uri.host =~ /amazon\.(com|ca|co\.uk|es|fr|de|it|com\.au|com\.br|cn|in|co\.jp|com\.mx)$/

      # default is 10k
      10
    end

    # Fetch the beginning of a HTML document at a url
    def self.fetch_beginning(url)
      # Never crawl in test mode
      return if Rails.env.test?

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
