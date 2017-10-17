require 'socket'
require 'ipaddr'
require 'excon'
require 'rate_limiter'

# Determine the final endpoint for a Web URI, following redirects
class FinalDestination

  def self.clear_https_cache!(domain)
    key = redis_https_key(domain)
    $redis.without_namespace.del(key)
  end

  def self.cache_https_domain(domain)
    key = redis_https_key(domain)
    $redis.without_namespace.setex(key, "1", 1.day.to_i).present?
  end

  def self.is_https_domain?(domain)
    key = redis_https_key(domain)
    $redis.without_namespace.get(key).present?
  end

  def self.redis_https_key(domain)
    "HTTPS_DOMAIN_#{domain}"
  end

  attr_reader :status, :cookie, :status_code

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
    @limited_ips = []
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
    if @uri && @uri.port == 80 && FinalDestination.is_https_domain?(@uri.hostname)
      @uri.scheme = "https"
      @uri = URI(@uri.to_s)
    end

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
    headers = nil

    response_status = response.status.to_i

    case response.status
    when 200
      @status = :resolved
      return @uri
    when 405, 409, 501
      get_response = small_get(headers)

      response_status = get_response.code.to_i
      if response_status == 200
        @status = :resolved
        return @uri
      end

      headers = {}
      if cookie_val = get_response.get_fields('set-cookie')
        headers['set-cookie'] = cookie_val.join
      end

      # TODO this is confusing why grap location for anything not
      # between 300-400 ?
      if location_val = get_response.get_fields('location')
        headers['location'] = location_val.join
      end
    end

    unless headers
      headers = {}
      response.headers.each do |k, v|
        headers[k.to_s.downcase] = v
      end
    end

    if (300..399).include?(response_status)
      location = headers["location"]
    end

    if set_cookie = headers["set-cookie"]
      @cookie = set_cookie
    end

    if location
      old_port = @uri.port

      location = "#{@uri.scheme}://#{@uri.host}#{location}" if location[0] == "/"
      @uri = URI(location) rescue nil
      @limit -= 1

      # https redirect, so just cache that whole new domain is https
      if old_port == 80 && @uri.port == 443 && (URI::HTTPS === @uri)
        FinalDestination.cache_https_domain(@uri.hostname)
      end

      return resolve
    end

    # this is weird an exception seems better
    @status = :failure
    @status_code = response.status

    nil
  rescue Excon::Errors::Timeout
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
    return true if hostname_matches?(SiteSetting.Upload.s3_cdn_url) ||
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
    if !@opts[:skip_rate_limit] && !@limited_ips.include?(address)
      @limited_ips << address
      RateLimiter.new(nil, "crawl-destination-ip:#{address_s}", 1000, 1.hour).performed!
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
