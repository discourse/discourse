# frozen_string_literal: true

require "addressable"

module Onebox
  module Helpers
    class DownloadTooLarge < StandardError
    end

    IGNORE_CANONICAL_DOMAINS = %w[www.instagram.com medium.com youtube.com].freeze

    def self.clean(html)
      html.gsub(/<[^>]+>/, " ").gsub(/\n/, "")
    end

    # Fetches the HTML response body for a URL.
    #
    # Note that the size of the response body is capped at `Onebox.options.max_download_kb`. When the limit has been reached,
    # this method will return the response body that has been downloaded up to the limit.
    def self.fetch_html_doc(url, headers = nil, body_cacher = nil)
      response =
        (
          begin
            fetch_response(url, headers:, body_cacher:, raise_error_when_response_too_large: false)
          rescue StandardError
            nil
          end
        )

      doc = Nokogiri.HTML(response)
      uri = Addressable::URI.parse(url)

      ignore_canonical_tag = doc.at('meta[property="og:ignore_canonical"]')
      should_ignore_canonical =
        IGNORE_CANONICAL_DOMAINS.map { |hostname| uri.hostname.match?(hostname) }.any?

      if !(ignore_canonical_tag && ignore_canonical_tag["content"].to_s == "true") &&
           !should_ignore_canonical
        # prefer canonical link
        canonical_link = doc.at('//link[@rel="canonical"]/@href')
        canonical_uri = Addressable::URI.parse(canonical_link)
        if canonical_link && canonical_uri &&
             "#{canonical_uri.host}#{canonical_uri.path}" != "#{uri.host}#{uri.path}"
          uri =
            FinalDestination.new(
              canonical_link,
              Oneboxer.get_final_destination_options(canonical_link),
            ).resolve
          if uri.present?
            response =
              (
                begin
                  fetch_response(
                    uri.to_s,
                    headers:,
                    body_cacher:,
                    raise_error_when_response_too_large: false,
                  )
                rescue StandardError
                  nil
                end
              )
            doc = Nokogiri.HTML(response) if response
          end
        end
      end

      doc
    end

    def self.fetch_response(
      location,
      redirect_limit: 5,
      domain: nil,
      headers: nil,
      body_cacher: nil,
      raise_error_when_response_too_large: true,
      allow_cross_domain_cookies: false
    )
      redirect_limit = Onebox.options.redirect_limit if redirect_limit >
        Onebox.options.redirect_limit

      raise Net::HTTPError.new("HTTP redirect too deep", location) if redirect_limit == 0

      uri = Addressable::URI.parse(location)
      uri = Addressable::URI.join(domain, uri) if !uri.host

      use_body_cacher = body_cacher && body_cacher.respond_to?("fetch_cached_response_body")
      if use_body_cacher
        response_body = body_cacher.fetch_cached_response_body(uri.to_s)

        return response_body if response_body.present?
      end

      result = StringIO.new
      FinalDestination::HTTP.start(
        uri.host,
        uri.port,
        open_timeout: Onebox.options.connect_timeout,
        use_ssl: uri.normalized_scheme == "https",
      ) do |http|
        http.read_timeout = Onebox.options.timeout
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Work around path building bugs

        headers ||= {}

        headers["User-Agent"] ||= user_agent if user_agent

        request = Net::HTTP::Get.new(uri.request_uri, headers)
        start_time = Time.now

        size_bytes = Onebox.options.max_download_kb * 1024
        http.request(request) do |response|
          if cookie = response.get_fields("set-cookie")
            headers["Cookie"] = cookie.join("; ") if allow_cross_domain_cookies
            # HACK: If this breaks again in the future, use HTTP::CookieJar from gem 'http-cookie'
            # See test: it "does not send cookies to the wrong domain"
            redir_header = { "Cookie" => cookie.join("; ") }
          end

          redir_header = nil unless redir_header.is_a? Hash

          code = response.code.to_i
          unless code === 200
            response.error! if [301, 302, 303, 307, 308].exclude?(code)

            return(
              fetch_response(
                response["location"],
                redirect_limit: redirect_limit - 1,
                domain: "#{uri.scheme}://#{uri.host}",
                headers: allow_cross_domain_cookies ? headers : redir_header,
                allow_cross_domain_cookies: allow_cross_domain_cookies,
              )
            )
          end

          response.read_body do |chunk|
            result.write(chunk)

            if result.size > size_bytes
              raise_error_when_response_too_large ? raise(DownloadTooLarge.new) : break
            end

            raise Timeout::Error.new if (Time.now - start_time) > Onebox.options.timeout
          end

          if use_body_cacher && body_cacher.cache_response_body?(uri)
            body_cacher.cache_response_body(uri.to_s, result.string)
          end

          return result.string
        end
      end
    end

    def self.fetch_content_length(location)
      uri = URI(location)

      FinalDestination::HTTP.start(
        uri.host,
        uri.port,
        open_timeout: Onebox.options.connect_timeout,
        use_ssl: uri.is_a?(URI::HTTPS),
      ) do |http|
        http.read_timeout = Onebox.options.timeout
        if uri.is_a?(URI::HTTPS)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        http.request_head([uri.path, uri.query].join("?")) do |response|
          return response.code.to_i == 200 ? response.content_length.presence : nil
        end
      end
    end

    def self.pretty_filesize(size)
      conv = %w[B KB MB GB TB PB EB]
      scale = 1024

      ndx = 1
      return "#{(size)} #{conv[ndx - 1]}" if (size < 2 * (scale**ndx))
      size = size.to_f
      [2, 3, 4, 5, 6, 7].each do |i|
        return "#{"%.2f" % (size / (scale**(i - 1)))} #{conv[i - 1]}" if (size < 2 * (scale**i))
      end
      ndx = 7
      "#{"%.2f" % (size / (scale**(ndx - 1)))} #{conv[ndx - 1]}"
    end

    def self.click_to_scroll_div(width = 690, height = 400)
      "<div style=\"background:transparent;position:relative;width:#{width}px;height:#{height}px;top:#{height}px;margin-top:-#{height}px;\" onClick=\"style.pointerEvents='none'\"></div>"
    end

    def self.truncate(string, length = 50)
      return string if string.nil?
      string.size > length ? string[0...(string.rindex(" ", length) || length)] + "..." : string
    end

    def self.get(meta, attr)
      (meta && meta[attr].present?) ? sanitize(meta[attr]) : nil
    end

    def self.sanitize(value, length = 50)
      return nil if value.blank?
      Sanitize.fragment(value).strip
    end

    def self.normalize_url_for_output(url)
      return "" unless url
      url = url.dup
      # expect properly encoded url, remove any unsafe chars
      url.gsub!(" ", "%20")
      url.gsub!("'", "&apos;")
      url.gsub!('"', "&quot;")
      url.gsub!(/[^\w\-`.~:\/?#\[\]@!$&'\(\)*+,;=%\p{M}’]/, "")

      parsed = Addressable::URI.parse(url)
      return "" unless parsed.host

      url
    end

    def self.get_absolute_image_url(src, url)
      begin
        URI.parse(url).merge(src).to_s
      rescue ArgumentError, URI::BadURIError, URI::InvalidURIError
        src
      end
    end

    def self.user_agent
      user_agent = SiteSetting.onebox_user_agent.presence || Onebox.options.user_agent
      user_agent = "#{user_agent} v#{Discourse::VERSION::STRING}"
      user_agent
    end

    # Percent-encodes a URI string per RFC3986 - https://tools.ietf.org/html/rfc3986
    def self.uri_encode(url)
      return "" unless url

      uri = Addressable::URI.parse(url)

      encoded_uri =
        Addressable::URI.new(
          scheme:
            Addressable::URI.encode_component(
              uri.scheme,
              Addressable::URI::CharacterClasses::SCHEME,
            ),
          authority:
            Addressable::URI.encode_component(
              uri.authority,
              Addressable::URI::CharacterClasses::AUTHORITY,
            ),
          path:
            Addressable::URI.encode_component(
              uri.path,
              Addressable::URI::CharacterClasses::PATH + "\\%",
            ),
          query:
            Addressable::URI.encode_component(
              uri.query,
              "a-zA-Z0-9\\-\\.\\_\\~\\$\\&\\*\\,\\=\\:\\@\\?\\%",
            ),
          fragment:
            Addressable::URI.encode_component(
              uri.fragment,
              "a-zA-Z0-9\\-\\.\\_\\~\\!\\$\\&\\'\\(\\)\\*\\+\\,\\;\\=\\:\\/\\?\\%",
            ),
        )

      encoded_uri.to_s
    end

    def self.uri_unencode(url)
      Addressable::URI.unencode(url)
    end

    def self.image_placeholder_html
      "<div class='onebox-placeholder-container'><span class='placeholder-icon image'></span></div>"
    end

    def self.video_placeholder_html
      "<div class='onebox-placeholder-container'><span class='placeholder-icon video'></span></div>"
    end

    def self.audio_placeholder_html
      "<div class='onebox-placeholder-container'><span class='placeholder-icon audio'></span></div>"
    end

    def self.map_placeholder_html
      "<div class='onebox-placeholder-container'><span class='placeholder-icon map'></span></div>"
    end

    def self.generic_placeholder_html
      "<div class='onebox-placeholder-container'><span class='placeholder-icon generic'></span></div>"
    end
  end
end
