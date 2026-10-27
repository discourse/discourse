# frozen_string_literal: true

module DiscourseAi
  module Agents
    module AppearanceAuthoring
      # Collects what a website's markup and styles say about its design: the
      # theme colors it declares, its web app manifest, CSS custom properties,
      # the rules for its links, buttons, header and headings, the colors in
      # its logo, and the fonts it loads.
      #
      # Everything is fetched through FinalDestination, which refuses private
      # and internal addresses, within size and time limits. The page's scripts
      # never run, the only redirect followed inside the page is one meta
      # refresh, and its visible text is left out.
      class WebsitePage
        MAX_PAGE_BYTES = 3.megabytes
        MAX_MANIFEST_BYTES = 200.kilobytes
        MAX_STYLESHEETS = 8
        MAX_STYLESHEET_BYTES = 2.megabytes
        MAX_CSS_BYTES = 4.megabytes
        MAX_ELEMENTS = 25
        MAX_LOGO_COLORS = 12
        MAX_VALUE_LENGTH = 200
        # How much CSS each kind of rule can contribute, so a long list of
        # design tokens can't crowd out the rules for buttons and links.
        CSS_BUDGETS = { root: 6_000, key: 8_000, other: 4_000 }.freeze

        TIME_BUDGET = 20
        REQUEST_TIMEOUT = 5
        MIN_REQUEST_TIME = 1
        MAX_REDIRECTS = 3

        DESIGN_PROPERTIES = %w[
          color
          background
          background-color
          border-color
          fill
          font-family
          border-radius
        ].freeze
        ROOT_SELECTOR = /\A(?::root|html|body)\z/
        KEY_SELECTOR =
          /(?:\A|[\s>+~])(?:a|button|h[1-3])(?:\z|[\s.:#\[>+~])|btn|button|cta|primary|header|nav|banner|brand|logo/i
        # variables a utility framework uses internally, which say nothing
        # about a brand
        IGNORED_VARIABLE = /\A--tw-/
        IGNORED_MEDIA = /print|prefers-color-scheme\s*:\s*dark/i
        NESTED_RULE_BLOCKS = %w[media supports layer container].freeze
        KEY_ELEMENTS =
          "header, nav, [role=banner], button, [role=button], a[class*=btn], a[class*=button], a[class*=cta]"
        LOGO_SVGS = "header svg, nav svg, [class*=logo] svg"
        SVG_STYLE_COLOR = /(?:fill|stroke|stop-color)\s*:\s*([^;]+)/
        IGNORED_SVG_COLORS = %w[none currentcolor transparent inherit].freeze

        attr_reader :url

        def initialize(url)
          @url = url
          @deadline = now + TIME_BUDGET
        end

        # Returns the evidence as a Hash, or nil when the page can't be read.
        def evidence
          return if !load_page

          {
            url: @url,
            theme_colors:,
            mask_icon_color: attribute('link[rel~="mask-icon"]', "color"),
            color_scheme: attribute('meta[name="color-scheme"]', "content"),
            manifest: manifest_colors,
            fonts_loaded: google_fonts,
            logo_colors:,
            elements: key_elements.map { |element| describe(element) }.compact_blank.uniq,
            css: css_excerpt,
          }.compact_blank
        end

        private

        def load_page
          @url, @document = fetch_document(@url)
          return false if @document.nil?

          if (target = refresh_target)
            url, document = fetch_document(target)
            @url, @document = url, document if document
          end
          true
        end

        def fetch_document(url)
          body, final_url = fetch(url, max_bytes: MAX_PAGE_BYTES, accept: "text/html")
          [final_url, Nokogiri.HTML5(body)] if body.present?
        rescue ArgumentError
          # markup the parser refuses, such as trees nested too deeply
          nil
        end

        def refresh_target
          refresh =
            @document
              .css("meta[http-equiv]")
              .find { |meta| meta["http-equiv"].to_s.casecmp?("refresh") }
          absolute_url(refresh&.[]("content").to_s[/url\s*=\s*['"]?([^'"\s]+)/i, 1])
        end

        def attribute(selector, name)
          @document.at_css(selector)&.[](name).to_s.strip.truncate(MAX_VALUE_LENGTH).presence
        end

        def theme_colors
          @document
            .css('meta[name="theme-color"]')
            .filter_map do |meta|
              content = meta["content"].to_s.strip
              next if content.blank?

              {
                content: content.truncate(MAX_VALUE_LENGTH),
                media: meta["media"].to_s.strip.truncate(MAX_VALUE_LENGTH),
              }.compact_blank
            end
            .uniq
        end

        def manifest_colors
          href = absolute_url(@document.at_css('link[rel~="manifest"]')&.[]("href"))
          return if href.nil?

          body, =
            fetch(
              href,
              max_bytes: MAX_MANIFEST_BYTES,
              accept: "application/manifest+json, application/json",
            )
          manifest = JSON.parse(body) if body.present?
          return if !manifest.is_a?(Hash)

          manifest
            .slice("theme_color", "background_color")
            .transform_values { |value| value.to_s.truncate(MAX_VALUE_LENGTH) }
            .compact_blank
        rescue JSON::ParserError
          nil
        end

        def google_fonts
          @document
            .css('link[href*="fonts.googleapis.com"]')
            .flat_map do |link|
              URI
                .decode_www_form(URI(link["href"]).query.to_s)
                .filter_map { |name, value| value if name == "family" }
                .flat_map { |value| value.split("|") }
                .map { |family| family.split(":").first.to_s.truncate(MAX_VALUE_LENGTH) }
            rescue URI::Error, ArgumentError
              []
            end
            .compact_blank
            .uniq
        end

        def logo_colors
          @document
            .css(LOGO_SVGS)
            .flat_map do |svg|
              values = svg.xpath("./@fill | .//@fill | .//@stroke | .//@stop-color").map(&:value)
              styles = svg.xpath("./@style | .//@style").map(&:value)
              values + styles.flat_map { |style| style.scan(SVG_STYLE_COLOR).flatten }
            end
            .map { |value| value.strip.truncate(MAX_VALUE_LENGTH) }
            .reject { |value| value.blank? || IGNORED_SVG_COLORS.include?(value.downcase) }
            .uniq
            .first(MAX_LOGO_COLORS)
        end

        def key_elements
          @key_elements ||= @document.css(KEY_ELEMENTS).first(MAX_ELEMENTS)
        end

        # The tag with the classes and inline style that show which CSS rules
        # apply to it. Elements without either say nothing about the design.
        def describe(element)
          description = {
            class: element["class"].to_s.squish.truncate(MAX_VALUE_LENGTH),
            style: element["style"].to_s.squish.truncate(MAX_VALUE_LENGTH),
          }.compact_blank
          { tag: element.name, **description } if description.present?
        end

        # Root rules first, then the rules for links, buttons, headers,
        # headings and the classes those elements use, then other rules that
        # set a color, each kind within its own budget.
        def css_excerpt
          key_classes = key_elements.flat_map(&:classes).to_set
          lines = Hash.new { |hash, kind| hash[kind] = [] }
          css_rules.each do |selectors, declarations|
            kind = rule_kind(selectors, declarations, key_classes)
            next if kind.nil?

            properties = declarations.map { |name, value| "#{name}: #{value}" }.join("; ")
            lines[kind] << "#{selectors.join(", ")} { #{properties} }"
          end

          CSS_BUDGETS
            .flat_map { |kind, budget| within_budget(lines[kind].uniq, budget) }
            .join("\n")
            .presence
        end

        def rule_kind(selectors, declarations, key_classes)
          return :root if selectors.any? { |selector| selector.match?(ROOT_SELECTOR) }
          return :key if selectors.any? { |selector| key_selector?(selector, key_classes) }

          :other if declarations.any? { |name, _| !name.start_with?("--") }
        end

        def key_selector?(selector, key_classes)
          return true if selector.match?(KEY_SELECTOR)

          class_name = selector.delete("\\")
          class_name.start_with?(".") && key_classes.include?(class_name[1..])
        end

        def within_budget(lines, budget)
          used = 0
          lines.take_while { |line| (used += line.length + 1) <= budget }
        end

        def css_rules
          sources = @document.css("style").map(&:text)
          stylesheet_urls
            .first(MAX_STYLESHEETS)
            .each do |href|
              break if sources.sum(&:bytesize) >= MAX_CSS_BYTES

              body, = fetch(href, max_bytes: MAX_STYLESHEET_BYTES, accept: "text/css")
              sources << body if body.present?
            end

          budget = MAX_CSS_BYTES
          sources.each_with_object([]) do |css, rules|
            break rules if budget <= 0

            css = css.byteslice(0, budget).scrub("")
            budget -= css.bytesize
            each_rule(Crass.parse(css)) { |rule| rules << rule }
          end
        end

        # Font stylesheets only declare font files, which the links already name.
        def stylesheet_urls
          @document
            .css('link[rel~="stylesheet"], link[rel~="preload"][as="style"]')
            .reject do |link|
              link["media"].to_s.match?(IGNORED_MEDIA) ||
                link["href"].to_s.include?("fonts.googleapis.com")
            end
            .filter_map { |link| absolute_url(link["href"]) }
            .uniq
        end

        def each_rule(nodes, &block)
          nodes.each do |node|
            case node[:node]
            when :style_rule
              declarations = design_declarations(node[:children])
              next if declarations.empty?

              selectors = node[:selector][:value].to_s.split(",").map(&:squish).compact_blank
              yield [selectors, declarations]
            when :at_rule
              next if node[:block].blank? || NESTED_RULE_BLOCKS.exclude?(node[:name].to_s.downcase)
              next if Crass::Parser.stringify(node[:prelude]).match?(IGNORED_MEDIA)

              each_rule(Crass::Parser.parse_rules(node[:block]), &block)
            end
          end
        end

        def design_declarations(nodes)
          nodes.filter_map do |node|
            next if node[:node] != :property

            name = node[:name].to_s.downcase
            value = node[:value].to_s.squish
            next if value.blank? || value.length > MAX_VALUE_LENGTH
            next if name.match?(IGNORED_VARIABLE)

            [name, value] if DESIGN_PROPERTIES.include?(name) || name.start_with?("--")
          end
        end

        def fetch(url, max_bytes:, accept:)
          return if remaining < MIN_REQUEST_TIME

          body = +""
          content_type = nil
          destination =
            FinalDestination.new(
              url,
              timeout: [REQUEST_TIMEOUT, remaining].min,
              max_redirects: MAX_REDIRECTS,
              headers: {
                "Accept" => accept,
              },
            )
          final_url =
            destination.get do |response, chunk, _uri|
              next if chunk.nil?

              content_type ||= response["content-type"]
              body << chunk
              throw :done if body.bytesize > max_bytes || remaining <= 0
            end
          return if final_url.nil? || body.empty?

          [to_utf8(body.byteslice(0, max_bytes), content_type), final_url]
        rescue StandardError
          # an unreachable or misbehaving site only means less evidence
          nil
        end

        def to_utf8(body, content_type)
          charset = Encodings.charset_from_content_type(content_type) || "utf-8"
          text = body.force_encoding(charset)
          if text.encoding != Encoding::UTF_8
            text = text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
          end
          text.scrub("")
        end

        def absolute_url(href)
          return if href.blank?

          url = URI.join(@url, href.strip)
          url.to_s if %w[http https].include?(url.scheme)
        rescue URI::Error, ArgumentError
          nil
        end

        def remaining
          @deadline - now
        end

        def now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
