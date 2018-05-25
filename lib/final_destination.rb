require 'socket'
require 'ipaddr'
require 'excon'
require 'rate_limiter'
require 'url_helper'

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
    @uri = uri(escape_url) if @url

    @opts = opts || {}
    @force_get_hosts = @opts[:force_get_hosts] || []
    @opts[:max_redirects] ||= 5
    @opts[:lookup_ip] ||= lambda { |host| FinalDestination.lookup_ip(host) }
    @ignored = [Discourse.base_url_no_prefix] + (@opts[:ignore_redirects] || [])
    @limit = @opts[:max_redirects]
    @status = :ready
    @http_verb = @force_get_hosts.any? { |host| hostname_matches?(host) } ? :get : :head
    @cookie = nil
    @limited_ips = []
    @verbose = @opts[:verbose] || false
    @timeout = @opts[:timeout] || nil
  end

  def self.connection_timeout
    20
  end

  def timeout
    @timeout || FinalDestination.connection_timeout
  end

  def redirected?
    @limit < @opts[:max_redirects]
  end

  def request_headers
    result = {
      "User-Agent" => "Mozilla/5.0 (Windows NT 6.2; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36",
      "Accept" => "*/*",
      "Host" => @uri.hostname
    }

    result['Cookie'] = @cookie if @cookie

    result
  end

  def small_get(headers)
    Net::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.is_a?(URI::HTTPS)) do |http|
      http.open_timeout = timeout
      http.read_timeout = timeout
      http.request_get(@uri.request_uri, headers)
    end
  end

  # this is a new interface for simply getting
  # N bytes accounting for all internal logic
  def get(uri = @uri, redirects = @limit, extra_headers: {}, &blk)
    raise "Must specify block" unless block_given?

    if uri && uri.port == 80 && FinalDestination.is_https_domain?(uri.hostname)
      uri.scheme = "https"
      uri = URI(uri.to_s)
    end

    return nil unless validate_uri

    result, (location, cookie) = safe_get(uri, &blk)

    if result == :redirect && (redirects == 0 || !location)
      return nil
    end

    if result == :redirect
      old_port = uri.port
      location = "#{uri.scheme}://#{uri.host}#{location}" if location[0] == "/"
      uri = uri(location)

      # https redirect, so just cache that whole new domain is https
      if old_port == 80 && uri&.port == 443 && (URI::HTTPS === uri)
        FinalDestination.cache_https_domain(uri.hostname)
      end

      return nil if !uri

      extra = nil
      extra = { 'Cookie' => cookie } if cookie

      get(uri, redirects - 1, extra_headers: extra, &blk)
    elsif result == :ok
      uri.to_s
    else
      nil
    end
  end

  def resolve
    if @uri && @uri.port == 80 && FinalDestination.is_https_domain?(@uri.hostname)
      @uri.scheme = "https"
      @uri = URI(@uri.to_s)
    end

    if @limit < 0
      @status = :too_many_redirects
      log(:warn, "FinalDestination could not resolve URL (too many redirects): #{@uri}") if @verbose
      return nil
    end

    @ignored.each do |host|
      if hostname_matches?(host)
        @status = :resolved
        return @uri
      end
    end

    unless validate_uri
      log(:warn, "FinalDestination could not resolve URL (invalid URI): #{@uri}") if @verbose
      return nil
    end

    headers = request_headers
    response = Excon.public_send(@http_verb,
      @uri.to_s,
      read_timeout: timeout,
      headers: headers
    )

    location = nil
    response_headers = nil

    response_status = response.status.to_i

    case response.status
    when 200
      @status = :resolved
      return @uri
    when 400, 405, 406, 409, 501
      get_response = small_get(request_headers)

      response_status = get_response.code.to_i
      if response_status == 200
        @status = :resolved
        return @uri
      end

      response_headers = {}
      if cookie_val = get_response.get_fields('set-cookie')
        response_headers[:cookies] = cookie_val
      end

      if location_val = get_response.get_fields('location')
        response_headers[:location] = location_val.join
      end
    end

    unless response_headers
      response_headers = {
        cookies: response.data[:cookies] || response.headers[:"set-cookie"],
        location: response.headers[:location]
      }
    end

    if (300..399).include?(response_status)
      location = response_headers[:location]
    end

    if cookies = response_headers[:cookies]
      @cookie = Array.wrap(cookies).map { |c| c.split(';').first.strip }.join('; ')
    end

    if location
      old_port = @uri.port
      location = "#{@uri.scheme}://#{@uri.host}#{location}" if location[0] == "/"
      @uri = uri(location)
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

    log(:warn, "FinalDestination could not resolve URL (status #{response.status}): #{@uri}") if @verbose
    nil
  rescue Excon::Errors::Timeout
    log(:warn, "FinalDestination could not resolve URL (timeout): #{@uri}") if @verbose
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
    url = uri(url)
    @uri && url.present? && @uri.hostname == url&.hostname
  end

  def is_dest_valid?
    return false unless @uri && @uri.host

    # Whitelisted hosts
    return true if hostname_matches?(SiteSetting.Upload.s3_cdn_url) ||
      hostname_matches?(GlobalSetting.try(:cdn_url)) ||
      hostname_matches?(Discourse.base_url_no_prefix)

    if SiteSetting.whitelist_internal_hosts.present?
      return true if SiteSetting.whitelist_internal_hosts.split("|").any? { |h| h.downcase == @uri.hostname.downcase }
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
    UrlHelper.escape_uri(
      CGI.unescapeHTML(@url),
      Regexp.new("[^#{URI::PATTERN::UNRESERVED}#{URI::PATTERN::RESERVED}#]")
    )
  end

  def private_ranges
    FinalDestination.standard_private_ranges +
      SiteSetting.blacklist_ip_blocks.split('|').map { |r| IPAddr.new(r) rescue nil }.compact
  end

  def log(log_level, message)
    return if @status_code == 404

    Rails.logger.public_send(
      log_level,
      "#{RailsMultisite::ConnectionManagement.current_db}: #{message}"
    )
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
    if Rails.env.test?
      "0.0.0.0"
    else
      IPSocket::getaddress(host)
    end
  rescue SocketError
    nil
  end

  protected

  def safe_get(uri)
    result = nil
    unsafe_close = false

    safe_session(uri) do |http|
      headers = request_headers.merge(
        'Accept-Encoding' => 'gzip',
        'Host' => uri.host
      )

      req = Net::HTTP::Get.new(uri.request_uri, headers)

      http.request(req) do |resp|
        if Net::HTTPRedirection === resp
          result = :redirect, [resp['location'], resp['Set-Cookie']]
        end

        if Net::HTTPSuccess === resp
          resp.decode_content = true
          resp.read_body do |chunk|
            read_next = true

            catch(:done) do
              if read_next
                read_next = false
                yield resp, chunk, uri
                read_next = true
              end
            end

            # no clean way of finishing abruptly cause
            # response likes reading till the end
            if !read_next
              unsafe_close = true
              http.finish
              raise StandardError
            end
          end
          result = :ok
        else
          catch(:done) do
            yield resp, nil, nil
          end
        end
      end
    end

    result
  rescue StandardError
    unsafe_close ? :ok : raise
  end

  def safe_session(uri)
    Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == "https")) do |http|
      http.read_timeout = timeout
      http.open_timeout = timeout
      yield http
    end
  end

  private

  def uri(location)
    begin
      URI(location)
    rescue URI::InvalidURIError, ArgumentError
    end
  end

end
