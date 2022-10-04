# frozen_string_literal: true

require 'socket'
require 'ipaddr'
require 'excon'
require 'rate_limiter'
require 'url_helper'

# Determine the final endpoint for a Web URI, following redirects
class FinalDestination
  MAX_REQUEST_TIME_SECONDS = 10
  MAX_REQUEST_SIZE_BYTES = 1_048_576 # 1024 * 1024

  def self.clear_https_cache!(domain)
    key = redis_https_key(domain)
    Discourse.redis.without_namespace.del(key)
  end

  def self.cache_https_domain(domain)
    key = redis_https_key(domain)
    Discourse.redis.without_namespace.setex(key, 1.day.to_i, "1")
  end

  def self.is_https_domain?(domain)
    key = redis_https_key(domain)
    Discourse.redis.without_namespace.get(key).present?
  end

  def self.redis_https_key(domain)
    "HTTPS_DOMAIN_#{domain}"
  end

  DEFAULT_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15"

  attr_reader :status, :cookie, :status_code, :content_type, :ignored

  def initialize(url, opts = nil)
    @url = url
    @uri = uri(escape_url) if @url

    @opts = opts || {}
    @force_get_hosts = @opts[:force_get_hosts] || []
    @preserve_fragment_url_hosts = @opts[:preserve_fragment_url_hosts] || []
    @force_custom_user_agent_hosts = @opts[:force_custom_user_agent_hosts] || []
    @default_user_agent = @opts[:default_user_agent] || DEFAULT_USER_AGENT
    @opts[:max_redirects] ||= 5

    @limit = @opts[:max_redirects]

    @ignored = []
    if @limit > 0
      ignore_redirects = [Discourse.base_url_no_prefix]

      if @opts[:ignore_redirects]
        ignore_redirects.concat(@opts[:ignore_redirects])
      end

      ignore_redirects.each do |ignore_redirect|
        ignore_redirect = uri(ignore_redirect)
        if ignore_redirect.present? && ignore_redirect.hostname
          @ignored << ignore_redirect.hostname
        end
      end
    end

    @status = :ready
    @follow_canonical = @opts[:follow_canonical]
    @http_verb = http_verb(@force_get_hosts, @follow_canonical)
    @cookie = nil
    @limited_ips = []
    @verbose = @opts[:verbose] || false
    @timeout = @opts[:timeout] || nil
    @preserve_fragment_url = @preserve_fragment_url_hosts.any? { |host| hostname_matches?(host) }
    @validate_uri = @opts.fetch(:validate_uri) { true }
    @user_agent = @force_custom_user_agent_hosts.any? { |host| hostname_matches?(host) } ? Onebox.options.user_agent : @default_user_agent
  end

  def self.connection_timeout
    20
  end

  def self.resolve(url)
    new(url).resolve
  end

  def http_verb(force_get_hosts, follow_canonical)
    if follow_canonical || force_get_hosts.any? { |host| hostname_matches?(host) }
      :get
    else
      :head
    end
  end

  def timeout
    @timeout || FinalDestination.connection_timeout
  end

  def redirected?
    @limit < @opts[:max_redirects]
  end

  def request_headers
    result = {
      "User-Agent" => @user_agent,
      "Accept" => "*/*",
      "Accept-Language" => "*",
      "Host" => @uri.hostname
    }

    result['Cookie'] = @cookie if @cookie

    result
  end

  def small_get(request_headers)
    status_code, response_headers = nil

    catch(:done) do
      FinalDestination::HTTP.start(@uri.host, @uri.port, use_ssl: @uri.is_a?(URI::HTTPS), open_timeout: timeout) do |http|
        http.read_timeout = timeout
        http.request_get(@uri.request_uri, request_headers) do |resp|
          status_code = resp.code.to_i
          response_headers = resp.to_hash

          # see: https://bugs.ruby-lang.org/issues/15624
          # if we allow response to return then body will be read
          # got to abort without reading body
          throw :done
        end
      end
    end

    [status_code, response_headers]
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

    unless validate_uri
      @status = :invalid_address
      log(:warn, "FinalDestination could not resolve URL (invalid URI): #{@uri}") if @verbose
      return nil
    end

    @ignored.each do |host|
      if @uri&.hostname&.match?(host)
        @status = :resolved
        return @uri
      end
    end

    if Oneboxer.cached_response_body_exists?(@uri.to_s)
      @status = :resolved
      return @uri
    end

    headers = request_headers
    middlewares = Excon.defaults[:middlewares]
    middlewares << Excon::Middleware::Decompress if @http_verb == :get

    request_start_time = Time.now
    response_body = +""
    request_validator = lambda do |chunk, _remaining_bytes, _total_bytes|
      response_body << chunk
      raise Excon::Errors::ExpectationFailed.new("response size too big: #{@uri.to_s}") if response_body.bytesize > MAX_REQUEST_SIZE_BYTES
      raise Excon::Errors::ExpectationFailed.new("connect timeout reached: #{@uri.to_s}") if Time.now - request_start_time > MAX_REQUEST_TIME_SECONDS
    end

    # This technique will only use the first resolved IP
    # TODO: Can we standardise this by using FinalDestination::HTTP?
    begin
      resolved_ip = SSRFDetector.lookup_and_filter_ips(@uri.hostname).first
    rescue SSRFDetector::DisallowedIpError, SocketError, Timeout::Error
      @status = :invalid_address
      return
    end
    request_uri = @uri.dup
    request_uri.hostname = resolved_ip unless Rails.env.test? # WebMock doesn't understand the IP-based requests

    response = Excon.public_send(@http_verb,
      request_uri.to_s,
      read_timeout: timeout,
      connect_timeout: timeout,
      headers: { "Host" => @uri.hostname }.merge(headers),
      middlewares: middlewares,
      response_block: request_validator,
      ssl_verify_peer_host: @uri.hostname
    )

    location = nil
    response_headers = nil
    response_status = response.status.to_i

    case response.status
    when 200
      # Cache body of successful `get` requests
      if @http_verb == :get
        if Oneboxer.cache_response_body?(@uri)
          Oneboxer.cache_response_body(@uri.to_s, response_body)
        end
      end

      if @follow_canonical
        next_url = fetch_canonical_url(response_body)

        if next_url.to_s.present? && next_url != @uri
          @follow_canonical = false
          @uri = next_url
          @http_verb = http_verb(@force_get_hosts, @follow_canonical)

          return resolve
        end
      end

      @content_type = response.headers['Content-Type'] if response.headers.has_key?('Content-Type')
      @status = :resolved
      return @uri
    when 103, 400, 405, 406, 409, 500, 501
      response_status, small_headers = small_get(request_headers)

      if response_status == 200
        @status = :resolved
        return @uri
      end

      response_headers = {}
      if cookie_val = small_headers['set-cookie']
        response_headers[:cookies] = cookie_val
      end

      if location_val = small_headers['location']
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
      redirect_uri = uri(location)
      if @uri.host == redirect_uri.host && (redirect_uri.path =~ /\/login/ || redirect_uri.path =~ /\/session/)
        @status = :resolved
        return @uri
      end

      old_port = @uri.port
      location = "#{location}##{@uri.fragment}" if @preserve_fragment_url && @uri.fragment.present?
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

  def skip_validations?
    !@validate_uri
  end

  def validate_uri
    skip_validations? || validate_uri_format
  end

  def validate_uri_format
    return false unless @uri && @uri.host
    return false unless ['https', 'http'].include?(@uri.scheme)
    return false if @uri.scheme == 'http' && @uri.port != 80
    return false if @uri.scheme == 'https' && @uri.port != 443

    # Disallow IP based crawling
    (IPAddr.new(@uri.hostname) rescue nil).nil?
  end

  def hostname
    @uri.hostname
  end

  def hostname_matches?(url)
    url = uri(url)

    if @uri&.hostname.present? && url&.hostname.present?
      hostname_parts = url.hostname.split('.')
      has_wildcard = hostname_parts.first == '*'

      if has_wildcard
        @uri.hostname.end_with?(hostname_parts[1..-1].join('.'))
      else
        @uri.hostname == url.hostname
      end
    end
  end

  def escape_url
    UrlHelper.escape_uri(@url)
  end

  def log(log_level, message)
    return if @status_code == 404

    Rails.logger.public_send(
      log_level,
      "#{RailsMultisite::ConnectionManagement.current_db}: #{message}"
    )
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

      req = FinalDestination::HTTP::Get.new(uri.request_uri, headers)

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
    FinalDestination::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == "https"), open_timeout: timeout) do |http|
      http.read_timeout = timeout
      yield http
    end
  end

  private

  def uri(location)
    begin
      URI.parse(location)
    rescue URI::Error
    end
  end

  def fetch_canonical_url(body)
    return if body.blank?

    canonical_element = Nokogiri::HTML5(body).at("link[rel='canonical']")
    return if canonical_element.nil?
    canonical_uri = uri(canonical_element['href'])
    return if canonical_uri.blank?

    return canonical_uri if canonical_uri.host.present?
    parts = [@uri.host, canonical_uri.to_s]
    complete_url = canonical_uri.to_s.starts_with?('/') ? parts.join('') : parts.join('/')
    complete_url = "#{@uri.scheme}://#{complete_url}" if @uri.scheme

    uri(complete_url)
  end
end
