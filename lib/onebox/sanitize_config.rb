# frozen_string_literal: true

module Onebox
  module SanitizeConfig
    HTTP_PROTOCOLS = ["http", "https", :relative].freeze

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
        ),
      )
  end
end
