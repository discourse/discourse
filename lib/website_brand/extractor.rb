# frozen_string_literal: true

module WebsiteBrand
  # Reads the color and font signals on a page, its web app manifest, its
  # stylesheets and its icon. The page's scripts never run, its forms are never
  # submitted, and the only HTML redirect followed is one meta refresh.
  class Extractor
    MAX_PAGE_BYTES = 3.megabytes
    MAX_MANIFEST_BYTES = 200.kilobytes
    MAX_STYLESHEETS = 8
    MAX_STYLESHEET_BYTES = 2.megabytes
    MAX_CSS_BYTES = 4.megabytes
    MAX_ICONS = 3
    MAX_ICON_BYTES = 1.megabyte
    MAX_ELEMENTS = 60
    MAX_FONT_STACK_LENGTH = 300
    # A class on many buttons is strong evidence, but no more than this many.
    MAX_CLASS_USES = 3
    # An icon's second color counts when it covers this share of the icon.
    MIN_SECOND_ICON_COLOR_SHARE = 0.2
    DARK_BACKGROUND_LIGHTNESS = 0.4
    DEFAULT_BACKGROUND = "ffffff"
    # A header this close to the page background doesn't stand out from it.
    HEADER_MIN_DISTANCE = Signals::CLUSTER_DISTANCE

    # How strongly each kind of signal points at the brand color.
    WEIGHTS = {
      theme_color: 4,
      primary_button: 4,
      link: 4,
      icon: 4,
      mask_icon: 3,
      manifest: 3,
      variable: 3,
      button_class: 3,
      button: 2,
      header: 2,
      icon_second_color: 1.5,
      nested_link: 0.5,
      background: 0.15,
      text: 0.1,
    }.freeze
    # The header element itself, or the wrappers just inside it.
    HEADER_DEPTH = 3

    ROOT = /\A(?::root|html|body)\z/
    HEADING = /\Ah[1-3]\z/
    PLAIN_LINK = /\Aa(?::link)?\z/
    NESTED_LINK = /(?:\A|[\s>+~])a(?::link)?(?:\z|[\s.#\[])/
    BUTTON = /(?:\b|_|-)(?:btn|button|cta|primary|signup|sign-up|get-?started)(?:\b|_|-)/i
    PRIMARY = /primary/i
    # Interaction states, decorations and dark variants don't show how a site
    # normally looks.
    IGNORED_SELECTOR = /:(?:hover|focus|active|visited|before|after)|dark/i
    IGNORED_MEDIA = /print|prefers-color-scheme\s*:\s*dark/i
    NESTED_RULE_BLOCKS = %w[media supports layer container].freeze
    BRAND_VARIABLE = /(?:\A--|-)(?:brand|primary|accent|cta)(?:-|\z)/
    # Variables named like a brand color that hold something else, or one
    # shade of a whole scale.
    NOT_BRAND_VARIABLE =
      /text|foreground|fg|border|muted|shadow|surface|neutral|gr[ae]y|on-|rgb|hsl|-(?:50|[1-46-9]00|950)\z/
    BACKGROUND_VARIABLES = %w[
      --background
      --bg
      --background-color
      --color-background
      --color-bg
    ].freeze
    BACKGROUND_PROPERTIES = %w[background background-color].freeze
    SINGLE_CLASS = /\A\.([^\s.:>+~\[\]()#,*]+)\z/
    INLINE_BACKGROUND = /background(?:-color)?\s*:\s*([^;]+)/i
    BUTTON_ELEMENTS = "button, a[class*=btn], a[class*=button], a[class*=cta], [role=button]"
    HEADER_ELEMENT = "header, [role=banner]"

    def initialize(url, fetcher: Fetcher.new)
      @url = url
      @fetcher = fetcher
      @signals = Signals.new
      @rules = []
      @root_variables = {}
      @other_variables = {}
    end

    # Returns a Profile, or nil when the page can't be read.
    def call
      return if !load_page

      read_meta_colors
      read_manifest
      read_icon
      read_stylesheets
      read_variables
      read_rules
      read_button_classes
      read_header

      background = page_background
      Profile.new(
        url: @page_url,
        confidence: @signals.confidence,
        brand: @signals.brand,
        accent: @signals.accent,
        header: header_color(background),
        background:,
        dark: dark?(background),
        candidates: @signals.candidates,
        body_font: Fonts.match(@body_font_stack || google_fonts.first),
        heading_font: Fonts.match(@heading_font_stack),
      )
    end

    private

    def load_page
      @page_url, @document = fetch_document(@url)
      return false if @document.nil?

      if (target = refresh_target)
        page_url, document = fetch_document(target)
        @page_url, @document = page_url, document if document
      end
      true
    end

    def fetch_document(url)
      response = @fetcher.text(url, max_bytes: MAX_PAGE_BYTES, accept: "text/html")
      [response.url, Nokogiri.HTML5(response.body)] if response
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

    def read_meta_colors
      @document
        .css('meta[name="theme-color"]')
        .each do |meta|
          next if meta["media"].to_s.match?(IGNORED_MEDIA)
          add_signal(Color.parse(meta["content"]), :theme_color)
        end
      @document
        .css('link[rel~="mask-icon"]')
        .each { |link| add_signal(Color.parse(link["color"]), :mask_icon) }
    end

    def read_manifest
      url = absolute_url(@document.at_css('link[rel~="manifest"]')&.[]("href"))
      return if url.nil?

      response =
        @fetcher.text(
          url,
          max_bytes: MAX_MANIFEST_BYTES,
          accept: "application/manifest+json, application/json",
        )
      manifest = JSON.parse(response.body) if response
      return if !manifest.is_a?(Hash)

      add_signal(Color.parse(manifest["theme_color"]), :manifest)
      @manifest_background = Color.parse(manifest["background_color"])
    rescue JSON::ParserError
      nil
    end

    # Uses the first icon with a vivid color, so later icons aren't fetched.
    def read_icon
      colors = icon_urls.first(MAX_ICONS).lazy.map { |url| vivid_icon_colors(url) }.find(&:present?)
      return if colors.nil?

      first, second = colors.sort_by { |hex, count| [-count, hex] }
      add_signal(first[0], :icon)
      if second && second[1] >= colors.values.sum * MIN_SECOND_ICON_COLOR_SHARE
        add_signal(second[0], :icon_second_color)
      end
    end

    def vivid_icon_colors(url)
      response = @fetcher.binary(url, max_bytes: MAX_ICON_BYTES)
      return {} if response.nil?

      IconColors.call(response.body).select { |hex, _| Color.vivid?(hex) }
    end

    def icon_urls
      touch_icons =
        @document.css('link[rel~="apple-touch-icon"], link[rel~="apple-touch-icon-precomposed"]')
      svg_icons, other_icons =
        @document
          .css('link[rel~="icon"]')
          .partition do |link|
            link["type"].to_s.include?("svg") ||
              link["href"].to_s.split("?").first.to_s.end_with?(".svg")
          end
      largest_first =
        other_icons
          .each_with_index
          .sort_by { |link, index| [-link["sizes"].to_i, index] }
          .map(&:first)

      [*touch_icons, *svg_icons, *largest_first].map { |link| absolute_url(link["href"]) }
        .push(absolute_url("/favicon.ico"))
        .compact
        .uniq
    end

    def read_stylesheets
      sources = @document.css("style").map(&:text)
      stylesheet_urls
        .first(MAX_STYLESHEETS)
        .each do |url|
          break if sources.sum(&:bytesize) >= MAX_CSS_BYTES

          response = @fetcher.text(url, max_bytes: MAX_STYLESHEET_BYTES, accept: "text/css")
          sources << response.body if response
        end

      budget = MAX_CSS_BYTES
      sources.each do |css|
        break if budget <= 0

        css = css.byteslice(0, budget).scrub("")
        budget -= css.bytesize
        each_rule(Crass.parse(css)) { |selectors, properties| record_rule(selectors, properties) }
      end
    end

    def stylesheet_urls
      @document
        .css('link[rel~="stylesheet"], link[rel~="preload"][as="style"]')
        .reject { |link| link["media"].to_s.match?(IGNORED_MEDIA) }
        .filter_map { |link| absolute_url(link["href"]) }
        .uniq
    end

    def each_rule(nodes, &block)
      nodes.each do |node|
        case node[:node]
        when :style_rule
          selectors = CssValue.split_arguments(node[:selector][:value].to_s.delete("\\"))
          yield selectors, properties(node[:children])
        when :at_rule
          next if node[:block].blank? || NESTED_RULE_BLOCKS.exclude?(node[:name].to_s.downcase)
          next if Crass::Parser.stringify(node[:prelude]).match?(IGNORED_MEDIA)

          each_rule(Crass::Parser.parse_rules(node[:block]), &block)
        end
      end
    end

    def properties(nodes)
      nodes.filter_map do |node|
        [node[:name].to_s.downcase, node[:value].to_s] if node[:node] == :property
      end
    end

    def record_rule(selectors, properties)
      selectors = selectors.reject { |selector| selector.match?(IGNORED_SELECTOR) }
      return if selectors.empty?

      root = root?(selectors)
      properties.each do |name, value|
        next if !name.start_with?("--")

        # the cascade lets later root values win; elsewhere a variable is only
        # a fallback for one the root doesn't define
        if root
          @root_variables[name] = value
        else
          @other_variables[name] ||= value
        end
      end
      @rules << [selectors, properties]
    end

    def read_variables
      @variables = @other_variables.merge(@root_variables)
      @variables.each do |name, value|
        next if !name.match?(BRAND_VARIABLE) || name.match?(NOT_BRAND_VARIABLE)
        add_signal(Color.parse(value, @variables), :variable)
      end
    end

    def read_rules
      @rules.each do |selectors, properties|
        properties.each do |name, value|
          case name
          when *BACKGROUND_PROPERTIES
            read_background(selectors, value)
          when "color"
            read_text_color(selectors, value)
          when "font-family"
            read_font(selectors, value)
          when "color-scheme"
            @declared_dark ||= root?(selectors) && value.strip.downcase.start_with?("dark")
          end
        end
      end
    end

    def read_background(selectors, value)
      hex = Color.first_in(value, @variables)
      return if hex.nil?

      if root?(selectors)
        @root_background = hex
      elsif matches?(selectors, BUTTON)
        add_signal(hex, matches?(selectors, PRIMARY) ? :primary_button : :button)
      else
        add_signal(hex, :background)
      end
    end

    def read_text_color(selectors, value)
      hex = Color.parse(value, @variables)
      return if hex.nil? || root?(selectors)

      if matches?(selectors, PLAIN_LINK)
        add_signal(hex, :link)
      elsif matches?(selectors, NESTED_LINK)
        add_signal(hex, :nested_link)
      else
        add_signal(hex, :text)
      end
    end

    def read_font(selectors, value)
      stack = CssValue.substitute_variables(value, @variables, max_length: MAX_FONT_STACK_LENGTH)
      return if stack.blank? || stack.match?(/\A\s*(?:inherit|initial|unset|revert)/i)

      if root?(selectors)
        @body_font_stack = stack
      elsif matches?(selectors, HEADING)
        @heading_font_stack = stack
      end
    end

    # Utility classes, such as Tailwind's, only show which colors matter on the
    # elements that use them.
    def read_button_classes
      uses = Hash.new(0)
      @document
        .css(BUTTON_ELEMENTS)
        .first(MAX_ELEMENTS)
        .each do |element|
          element.classes.each do |class_name|
            next if !class_backgrounds.key?(class_name) || uses[class_name] >= MAX_CLASS_USES

            uses[class_name] += 1
            class_backgrounds[class_name].each do |value|
              add_signal(Color.first_in(value, @variables), :button_class)
            end
          end
        end
    end

    # Reads the background of the page's header element. Class names that
    # merely mention a header, such as a table's header cells, say nothing
    # about it.
    def read_header
      element = @document.at_css(HEADER_ELEMENT)
      HEADER_DEPTH.times do
        break if element.nil?

        if (hex = element_background(element))
          @header_background = hex
          add_signal(hex, :header)
          break
        end
        element = element.element_children.first
      end
    end

    def element_background(element)
      inline = element["style"].to_s[INLINE_BACKGROUND, 1]
      hex = Color.first_in(inline, @variables) if inline
      hex ||
        element
          .classes
          .flat_map { |class_name| class_backgrounds.fetch(class_name, []) }
          .lazy
          .filter_map { |value| Color.first_in(value, @variables) }
          .first || element_rule_background(element)
    end

    # The background from the last rule that selects the element by its tag
    # or id alone.
    def element_rule_background(element)
      names = [element.name, ("##{element["id"]}" if element["id"].present?)].compact
      @rules.reverse_each do |selectors, properties|
        next if (selectors & names).empty?

        properties.reverse_each do |name, value|
          next if BACKGROUND_PROPERTIES.exclude?(name)
          hex = Color.first_in(value, @variables)
          return hex if hex
        end
      end
      nil
    end

    def header_color(background)
      return if @header_background.nil?
      @header_background if Color.distance(@header_background, background) >= HEADER_MIN_DISTANCE
    end

    # Background values set by rules that select a single class.
    def class_backgrounds
      @class_backgrounds ||=
        @rules.each_with_object({}) do |(selectors, properties), backgrounds|
          values =
            properties.filter_map { |name, value| value if BACKGROUND_PROPERTIES.include?(name) }
          next if values.empty?

          selectors.each do |selector|
            class_name = selector[SINGLE_CLASS, 1]
            (backgrounds[class_name] ||= []).concat(values) if class_name
          end
        end
    end

    def page_background
      @root_background || variable_background || @manifest_background || DEFAULT_BACKGROUND
    end

    def variable_background
      BACKGROUND_VARIABLES
        .lazy
        .filter_map { |name| Color.parse(@variables[name], @variables) if @variables[name] }
        .first
    end

    def dark?(background)
      color_scheme = @document.at_css('meta[name="color-scheme"]')&.[]("content").to_s
      color_scheme.strip.downcase.start_with?("dark") ||
        @document.at_css("html")&.classes.to_a.include?("dark") || !!@declared_dark ||
        Color.lightness(background) < DARK_BACKGROUND_LIGHTNESS
    end

    def google_fonts
      @document
        .css('link[href*="fonts.googleapis.com"]')
        .flat_map do |link|
          URI
            .decode_www_form(URI(link["href"]).query.to_s)
            .filter_map { |name, value| value if name == "family" }
            .flat_map { |value| value.split("|") }
            .map { |family| family.split(":").first }
        rescue URI::Error, ArgumentError
          []
        end
    end

    def add_signal(hex, source)
      @signals.add(hex, weight: WEIGHTS.fetch(source), source:)
    end

    def root?(selectors)
      matches?(selectors, ROOT)
    end

    def matches?(selectors, pattern)
      selectors.any? { |selector| selector.match?(pattern) }
    end

    def absolute_url(href)
      return if href.blank?

      url = URI.join(@page_url, href.strip)
      url.to_s if %w[http https].include?(url.scheme)
    rescue URI::Error, ArgumentError
      nil
    end
  end
end
