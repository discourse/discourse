# frozen_string_literal: true

module Onebox
  module SanitizeConfig
    HTTP_PROTOCOLS = ["http", "https", :relative].freeze
    AUTOLOADED_URL_ATTRIBUTES = {
      "audio" => %w[src],
      "embed" => %w[src],
      "iframe" => %w[src],
      "img" => %w[src srcset],
      "source" => %w[src srcset],
      "video" => %w[src poster],
    }.freeze

    def self.safe_media_url?(url)
      uri = URI.parse(url)
      return uri.scheme.nil? if uri.host.nil?
      return false unless uri.scheme.nil? || uri.scheme.in?(HTTP_PROTOCOLS)

      hostname = uri.hostname.downcase.delete_suffix(".")
      own_hostname = URI.parse(Discourse.base_url_no_prefix).hostname.downcase
      return true if hostname == own_hostname
      return false if hostname.include?("%")
      return false if hostname == "localhost" || !hostname.include?(".")
      if hostname.end_with?(
           ".localhost",
           ".local",
           ".localdomain",
           ".lan",
           ".internal",
           ".home.arpa",
         )
        return false
      end

      begin
        return FinalDestination::SSRFDetector.ip_allowed?(IPAddr.new(hostname))
      rescue IPAddr::InvalidAddressError
        return false if hostname.match?(/\A(?:0x[0-9a-f]+|\d+)(?:\.(?:0x[0-9a-f]+|\d+))*\z/i)
      end

      true
    rescue URI::InvalidURIError
      false
    end
    private_class_method :safe_media_url?

    ONEBOX =
      Sanitize::Config.freeze_config(
        Sanitize::Config.merge(
          Sanitize::Config::RELAXED,
          elements:
            Sanitize::Config::RELAXED[:elements] +
              %w[audio details embed iframe source video svg path use],
          attributes: {
            "a" => Sanitize::Config::RELAXED[:attributes]["a"] + %w[target],
            "audio" => %w[controls controlslist],
            "embed" => %w[height src type width],
            "iframe" => %w[
              allowfullscreen
              frameborder
              height
              scrolling
              src
              width
              data-original-href
              data-unsanitized-src
            ],
            "source" => %w[src type],
            "video" => %w[
              controls
              height
              loop
              width
              autoplay
              muted
              poster
              controlslist
              playsinline
            ],
            "path" => %w[d fill-rule],
            "svg" => %w[aria-hidden width height viewbox],
            "div" => [:data], # any data-* attributes,
            "span" => [:data], # any data-* attributes,
            "use" => %w[href],
          },
          add_attributes: {
            "iframe" => {
              "seamless" => "seamless",
              "sandbox" =>
                "allow-same-origin allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox" \
                  " allow-presentation",
            },
          },
          transformers:
            (Sanitize::Config::RELAXED[:transformers] || []) +
              [
                lambda do |env|
                  next unless env[:node_name] == "a"
                  a_tag = env[:node]
                  a_tag["href"] ||= "#"
                  if a_tag["href"] =~ %r{\A(?:[a-z]+:)?//}
                    a_tag["rel"] = "nofollow ugc noopener"
                  else
                    a_tag.remove_attribute("target")
                  end
                end,
                lambda do |env|
                  next unless env[:node_name] == "iframe"

                  iframe = env[:node]
                  allowed_regexes = env[:config][:allowed_iframe_regexes] || [/.*/]

                  allowed = allowed_regexes.any? { |r| iframe["src"] =~ r }

                  if !allowed
                    # add a data attribute with the blocked src. This is not required
                    # but makes it much easier to troubleshoot onebox issues
                    iframe["data-unsanitized-src"] = iframe["src"]
                    iframe.remove_attribute("src")
                  end
                end,
                lambda do |env|
                  next if env[:node_name] != "svg"
                  env[:node].traverse do |node|
                    next if node.element? && %w[svg path use].include?(node.name)
                    node.remove
                  end
                end,
              ],
          protocols: {
            "embed" => {
              "src" => HTTP_PROTOCOLS,
            },
            "iframe" => {
              "src" => HTTP_PROTOCOLS,
            },
            "source" => {
              "src" => HTTP_PROTOCOLS,
            },
            "use" => {
              "href" => [:relative],
            },
          },
          css: {
            properties: Sanitize::Config::RELAXED[:css][:properties] + %w[--aspect-ratio],
          },
        ),
      )

    DISCOURSE_ONEBOX =
      Sanitize::Config.freeze_config(
        Sanitize::Config.merge(
          ONEBOX,
          attributes: Sanitize::Config.merge(ONEBOX[:attributes], "aside" => [:data]),
          transformers:
            ONEBOX[:transformers] +
              [
                lambda do |env|
                  node = env[:node]
                  if env[:node_name] == "style"
                    node.remove
                    next
                  end

                  AUTOLOADED_URL_ATTRIBUTES
                    .fetch(env[:node_name], [])
                    .each do |attribute|
                      value = node[attribute]
                      next if value.blank?

                      urls =
                        if attribute == "srcset"
                          value.split(",").filter_map { |entry| entry.strip.split.first }
                        else
                          [value]
                        end
                      node.remove_attribute(attribute) if urls.any? { |url| !safe_media_url?(url) }
                    end
                end,
              ],
          css: Sanitize::Config.merge(ONEBOX[:css], protocols: []),
        ),
      )
  end
end
