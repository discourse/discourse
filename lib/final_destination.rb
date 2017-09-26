require "socket"
require "ipaddr"
require 'excon'
require 'rate_limiter'

# Determine the final endpoint for a Web URI, following redirects
class FinalDestination

  attr_reader :status
  attr_reader :cookie

  def initialize(url, opts = nil)
    @url = url
    @uri =
      begin
        URI(escape_url) if @url
      rescue URI::InvalidURIError
      end

    @opts = opts || {}
    @force_get_hosts = @opts[:force_get_hosts] || []
    @opts[:max_redirects] ||= 5
    @opts[:lookup_ip] ||= lambda do |host|
      begin
        IPSocket::getaddress(host)
      rescue SocketError
        nil
      end
    end
    @ignored = [Discourse.base_url_no_prefix] + (@opts[:ignore_redirects] || [])
    @limit = @opts[:max_redirects]
    @status = :ready
    @http_verb = @force_get_hosts.any? { |host| hostname_matches?(host) } ? :get : :head
    @cookie = nil
  end

  def self.connection_timeout
    20
  end

  def redirected?
    @limit < @opts[:max_redirects]
  end

  def request_headers
    result = {
      "User-Agent" => "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36",
      "Accept" => "text/html",
      "Host" => @uri.hostname
    }

    result['cookie'] = @cookie if @cookie

    result
  end

  def small_get(headers)
    Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.is_a?(URI::HTTPS)) do |http|
      http.open_timeout = FinalDestination.connection_timeout
      http.read_timeout = FinalDestination.connection_timeout

      request = Net::HTTP::Get.new(@uri.request_uri, headers)
      http.request(request) do |response|
        return response
      end
    end
  end

  def resolve
    if @limit < 0
      @status = :too_many_redirects
      return nil
    end

    @ignored.each do |host|
      if hostname_matches?(host)
        @status = :resolved
        return @uri
      end
    end

    return nil unless validate_uri
    headers = request_headers
    response = Excon.public_send(@http_verb,
      @uri.to_s,
      read_timeout: FinalDestination.connection_timeout,
      headers: headers
    )

    location = nil
    case response.status
    when 200
      @status = :resolved
      return @uri
    when 405, 409, 501
      get_response = small_get(headers)

      if get_response.code.to_i == 200
        @status = :resolved
        return @uri
      end

      if cookie_val = get_response.get_fields('set-cookie')
        @cookie = cookie_val.join
      end

      if location_val = get_response.get_fields('location')
        location = location_val.join
      end
    else
      response.headers.each do |k, v|
        case k.downcase
        when 'set-cookie' then @cookie = v
        when 'location' then location = v
        end
      end
    end

    if location
      location = "#{@uri.scheme}://#{@uri.host}#{location}" if location[0] == "/"
      @uri = URI(location) rescue nil
      @limit -= 1
      return resolve
    end

    nil
  end

  def validate_uri
    validate_uri_format && is_dest_valid?
  end

  def validate_uri_format
    return false unless @uri
    return false unless ['https', 'http'].include?(@uri.scheme)
    return false if @uri.scheme == 'http' && @uri.port != 80
    return false if @uri.scheme == 'https' && @uri.port != 443

    # Disallow IP based crawling
    (IPAddr.new(@uri.hostname) rescue nil).nil?
  end

  def hostname_matches?(url)
    @uri && url.present? && @uri.hostname == (URI(url) rescue nil)&.hostname
  end

  def is_dest_valid?

    return false unless @uri && @uri.host

    # Whitelisted hosts
    return true if hostname_matches?(SiteSetting.s3_cdn_url) ||
      hostname_matches?(GlobalSetting.try(:cdn_url)) ||
      hostname_matches?(Discourse.base_url_no_prefix)

    if SiteSetting.whitelist_internal_hosts.present?
      SiteSetting.whitelist_internal_hosts.split('|').each do |h|
        return true if @uri.hostname.downcase == h.downcase
      end
    end

    address_s = @opts[:lookup_ip].call(@uri.hostname)
    return false unless address_s

    address = IPAddr.new(address_s)

    if private_ranges.any? { |r| r === address }
      @status = :invalid_address
      return false
    end

    # Rate limit how often this IP can be crawled
    unless @opts[:skip_rate_limit]
      RateLimiter.new(nil, "crawl-destination-ip:#{address_s}", 100, 1.hour).performed!
    end

    true
  rescue RateLimiter::LimitExceeded
    false
  end

  def escape_url
    TopicEmbed.escape_uri(
      CGI.unescapeHTML(@url),
      Regexp.new("[^#{URI::PATTERN::UNRESERVED}#{URI::PATTERN::RESERVED}#]")
    )
  end

  def private_ranges
    FinalDestination.standard_private_ranges +
      SiteSetting.blacklist_ip_blocks.split('|').map { |r| IPAddr.new(r) rescue nil }.compact
  end

  def self.standard_private_ranges
    @private_ranges ||= [
      IPAddr.new('127.0.0.1'),
      IPAddr.new('172.16.0.0/12'),
      IPAddr.new('192.168.0.0/16'),
      IPAddr.new('10.0.0.0/8'),
      IPAddr.new('fc00::/7')
    ]
  end

  def self.lookup_ip(host)
    IPSocket::getaddress(host)
  end

end
