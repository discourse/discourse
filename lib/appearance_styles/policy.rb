# frozen_string_literal: true

# Checks typed theme styles and writes the CSS for them, so styles that come
# from somewhere untrusted (a language model, an import) can only make
# cosmetic changes. Styles never contain CSS text or selectors:
#
#   {
#     "variables" => { "--d-border-radius" => "12px" },
#     "rules" => [
#       { "area" => "topic_list_item", "state" => "hover", "media" => "desktop",
#         "declarations" => { "box-shadow" => "0 2px 8px rgba(var(--primary-rgb), 0.08)" } }
#     ]
#   }
#
# Variables override core design variables (AppearanceStyles::VariableRegistry).
# Rules restyle a named area (AppearanceStyles::AreaCatalog), and this class
# writes the selector. Every value is parsed and checked against the property's
# type and bounds, colors must follow the palette, text must stay readable in
# light and dark mode, and nothing applies to the admin area.
module AppearanceStyles
  class Policy
    MAX_VARIABLES = 60
    MAX_RULES = 40
    MAX_DECLARATIONS = 12
    MAX_VALUE_LENGTH = 200
    MAX_CSS_BYTES = 16 * 1024

    # Never style the admin area, so an admin can always get back to
    # Customize > Themes. Variables go on the root element because derived
    # variables (e.g. --d-button-border-radius: var(--d-border-radius)) are
    # resolved there; setting them on body would not reach those.
    ROOT_SCOPE = ":root:not(:has(> body.admin-interface))"
    BODY_SCOPE = "body:not(.admin-interface)"

    MEDIA = { "mobile" => "(max-width: 767px)", "desktop" => "(min-width: 768px)" }.freeze
    STATES = { "hover" => "hover", "odd" => "nth-child(odd)", "even" => "nth-child(even)" }.freeze
    PAGES = {
      "topic" => ".archetype-regular",
      "lists" => ".navigation-topics",
      "categories" => ".navigation-categories",
    }.freeze
    SIZE_PROPERTIES = %w[width height max-width max-height].freeze

    FORBIDDEN_CHARACTERS = ["\\", ";", "{", "}", "<", ">", "!", "@", "\"", "'", "`"].freeze
    FORBIDDEN_SUBSTRINGS = %w[
      url(
      expression
      javascript:
      image-set
      element(
      attr(
      env(
      /*
      */
    ].freeze

    ALLOWED_FUNCTIONS = %w[
      var
      calc
      min
      max
      clamp
      rgb
      rgba
      hsl
      hsla
      oklch
      color-mix
      light-dark
      linear-gradient
      radial-gradient
    ].freeze
    RAW_COLOR_FUNCTIONS = %w[rgb rgba hsl hsla oklch].freeze
    MATH_FUNCTIONS = %w[calc min max clamp].freeze
    COLOR_KEYWORDS = %w[transparent currentcolor inherit].freeze
    COLOR_SYNTAX_KEYWORDS = %w[in srgb oklch oklab hsl longer shorter hue].freeze
    GRADIENT_KEYWORDS = %w[
      to
      top
      bottom
      left
      right
      center
      circle
      ellipse
      at
      closest-side
      farthest-corner
    ].freeze
    LENGTH_UNITS = %w[px rem em %].freeze

    COLOR_PROPERTIES = %w[
      color
      background-color
      border-color
      border-top-color
      border-right-color
      border-bottom-color
      border-left-color
      outline-color
      text-decoration-color
      fill
      stroke
    ].freeze

    PROPERTY_SPECS = {
      "background" => [:background],
      "background-image" => [:gradient],
      "border" => [:border],
      "border-top" => [:border],
      "border-right" => [:border],
      "border-bottom" => [:border],
      "border-left" => [:border],
      "border-width" => [:length_list, 0, 8],
      "border-style" => [:keyword, %w[solid dashed dotted none]],
      "border-radius" => [:length_list, 0, 9999],
      "box-shadow" => [:shadow],
      "text-shadow" => [:text_shadow],
      "font-size" => [:length, 11, 48],
      "font-weight" => [:font_weight],
      "font-style" => [:keyword, %w[normal italic]],
      "font-family" => [:font_family],
      "line-height" => [:line_height],
      "letter-spacing" => [:signed_length, -2, 6],
      "text-transform" => [:keyword, %w[none uppercase lowercase capitalize]],
      "text-decoration" => [:keyword, %w[none underline]],
      "text-decoration-line" => [:keyword, %w[none underline]],
      "text-align" => [:keyword, %w[left center right start end]],
      "padding" => [:length_list, 0, 64],
      "padding-top" => [:length, 0, 64],
      "padding-right" => [:length, 0, 64],
      "padding-bottom" => [:length, 0, 64],
      "padding-left" => [:length, 0, 64],
      "margin" => [:length_list, 0, 64],
      "margin-top" => [:length, 0, 64],
      "margin-right" => [:length, 0, 64],
      "margin-bottom" => [:length, 0, 64],
      "margin-left" => [:length, 0, 64],
      "gap" => [:length, 0, 64],
      "row-gap" => [:length, 0, 64],
      "column-gap" => [:length, 0, 64],
      "opacity" => [:number, 0.6, 1],
      "transition" => [:transition],
      "display" => [:display],
    }.merge(COLOR_PROPERTIES.to_h { |property| [property, [:color]] }).freeze

    TRANSITION_PROPERTIES = %w[color background-color border-color box-shadow opacity].freeze
    EASINGS = %w[ease ease-in ease-out ease-in-out linear].freeze

    Change = Data.define(:label, :value)
    Result =
      Data.define(:css, :errors, :changes) do
        def valid?
          errors.empty?
        end
      end

    # palettes: { "light" => { "primary" => "222222", ... }, "dark" => { ... } }
    # Contrast checks resolve colors against these; Foundation's built-in
    # palettes are used when the draft does not bring its own.
    MINIMUM_CONTRAST = 4.5
    MINIMUM_ICON_CONTRAST = 3.0

    # styles: the typed styles described above.
    # palettes: the colors the styles will be shown with, as
    # { "light" => { "primary" => "222222", ... }, "dark" => { ... } }.
    # Without them, contrast is checked against core's own light and dark
    # palettes.
    def self.call(styles, palettes: nil)
      new(
        styles,
        registry: VariableRegistry.instance,
        catalog: AreaCatalog.instance,
        palettes:,
      ).call
    end

    def initialize(styles, registry:, catalog:, palettes: nil)
      @draft = styles.is_a?(Hash) ? styles.deep_stringify_keys : {}
      @registry = registry
      @catalog = catalog
      @palette_colors = palette_colors(palettes&.deep_stringify_keys)
      @errors = []
      @changes = []
    end

    def call
      variables = @draft["variables"] || {}
      rules = @draft["rules"] || []
      unknown = @draft.keys - %w[variables rules]
      error("styles", "unknown keys: #{unknown.join(", ")}") if unknown.any?
      error("variables", "must be an object") if !variables.is_a?(Hash)
      error("rules", "must be a list") if !rules.is_a?(Array)
      return result(nil) if @errors.any?

      error("variables", "at most #{MAX_VARIABLES}") if variables.size > MAX_VARIABLES
      error("rules", "at most #{MAX_RULES}") if rules.size > MAX_RULES
      return result(nil) if @errors.any?

      @draft_variables = variables
      root_declarations = []
      scoped_declarations = Hash.new { |hash, key| hash[key] = [] }

      variables.each do |name, value|
        variable = check_variable(name, value, "variables.#{name}")
        next if !variable

        if variable.root?
          root_declarations << "#{name}: #{normalize(value)}"
        else
          variable
            .selectors
            .map { |selector| selector.split(" @media").first }
            .uniq
            .each { |selector| scoped_declarations[selector] << "#{name}: #{normalize(value)}" }
        end
        @changes << Change.new(label: "#{name}", value: normalize(value))
      end

      readable_variables?(variables) if @errors.empty?

      blocks = []
      blocks << block(ROOT_SCOPE, root_declarations) if root_declarations.any?
      scoped_declarations.each do |selector, declarations|
        blocks << block(scope_selector(selector), declarations)
      end

      @checked_rules = []
      rules.each_with_index { |rule, index| blocks.concat(check_rule(rule, "rules[#{index}]")) }
      readable_together? if @errors.empty?
      readable_nested? if @errors.empty?

      css = blocks.join("\n")
      if css.bytesize > MAX_CSS_BYTES
        error("styles", "generated CSS is #{css.bytesize} bytes, over #{MAX_CSS_BYTES}")
      end
      result(@errors.empty? ? css : nil)
    end

    private

    def result(css)
      Result.new(css:, errors: @errors, changes: @changes)
    end

    def error(path, message)
      @errors << "#{path}: #{message}"
      nil
    end

    def block(selector, declarations)
      "#{selector} {\n#{declarations.map { |declaration| "  #{declaration};" }.join("\n")}\n}"
    end

    def scope_selector(selector, state = nil, page = nil)
      body = page ? BODY_SCOPE.sub("body", "body#{PAGES.fetch(page)}") : BODY_SCOPE
      pseudo = state && STATES.fetch(state)
      selector
        .split(",")
        .map(&:strip)
        .map { |part| part == "&" ? body : "#{body} #{part}" }
        .map { |part| pseudo ? "#{part}:#{pseudo}" : part }
        .join(", ")
    end

    def normalize(value)
      value.to_s.strip.gsub(/\s+/, " ")
    end

    def check_variable(name, value, path)
      variable = @registry[name.to_s]
      return error(path, "unknown variable") if !variable
      return error(path, "not authorable (#{variable.reason})") if !variable.allowed

      nodes = parse(value, path)
      return if !nodes

      ok =
        case variable.type
        when "color"
          check_color(nodes, path)
        when "length"
          check_length(
            nodes,
            path,
            variable.min_px,
            variable.max_px,
            percent: length_percent(variable.name),
          )
        when "border"
          check_border(nodes, path)
        when "keyword"
          check_keyword(nodes, path, variable.keywords)
        when "font_weight"
          check_font_weight(nodes, path)
        else
          error(path, "type #{variable.type} is not supported")
        end
      ok ? variable : nil
    end

    def check_rule(rule, path)
      return [error(path, "must be an object")].compact if !rule.is_a?(Hash)
      rule = rule.stringify_keys
      allowed_keys = %w[area state media page declarations]
      unknown = rule.keys - allowed_keys
      return [error(path, "unknown keys: #{unknown.join(", ")}")].compact if unknown.any?

      area = @catalog[rule["area"]]
      return [error(path, "unknown area #{rule["area"].inspect}")].compact if !area

      state = rule["state"].presence
      if state && (!STATES.key?(state) || !area.states.include?(state))
        return [error(path, "state #{state.inspect} is not allowed for #{area.key}")].compact
      end

      page = rule["page"].presence
      if page && !PAGES.key?(page)
        return [error(path, "page must be one of #{PAGES.keys.join(", ")}")].compact
      end

      media = rule["media"].presence
      if media && !MEDIA.key?(media)
        return [error(path, "media must be one of #{MEDIA.keys.join(", ")}")].compact
      end

      declarations = rule["declarations"]
      if !declarations.is_a?(Hash) || declarations.empty?
        return [error(path, "declarations must be a non-empty object")].compact
      end
      if declarations.size > MAX_DECLARATIONS
        return [error(path, "at most #{MAX_DECLARATIONS} declarations")].compact
      end

      # Variables a rule sets apply within its area, so its checks see them.
      overrides = declarations.select { |property, _| property.to_s.start_with?("--") }
      overrides = overrides.transform_keys(&:to_s)
      global_variables = @draft_variables
      @draft_variables = global_variables.merge(overrides)

      rendered = []
      declarations.each do |property, value|
        property = property.to_s
        declaration_path = "#{path}.#{property}"
        ok =
          if property.start_with?("--")
            check_variable(property, value, declaration_path)
          else
            check_property(property, value, declaration_path, area)
          end
        next if !ok
        rendered << "#{property}: #{normalize(value)}"
        @changes << Change.new(
          label: [area.label, state].compact.join(" (") + (state ? ")" : "") + " #{property}",
          value: normalize(value),
        )
      end
      return [] if rendered.size != declarations.size
      return [] if !readable?(declarations, path, area, state)
      return [] if overrides.any? && !readable_variables?(overrides, path)

      @checked_rules << {
        path:,
        area:,
        state:,
        media:,
        page:,
        declarations: declarations.transform_keys(&:to_s),
        overrides:,
      }

      css = block(scope_selector(area.selector, state, page), rendered)
      css = "@media #{MEDIA[media]} {\n#{css.gsub(/^/, "  ")}\n}" if media
      [css]
    ensure
      @draft_variables = global_variables if global_variables
    end

    def check_property(property, value, path, area)
      spec = PROPERTY_SPECS[property]
      if !spec && area.sizeable && SIZE_PROPERTIES.include?(property)
        return true if value.to_s.strip == "auto"
        spec = [:length, 16, 480]
      end
      return error(path, "property is not allowed") if !spec

      nodes = parse(value, path)
      return if !nodes

      kind, *args = spec
      case kind
      when :color
        check_color(nodes, path)
      when :background
        if nodes.size == 1 && nodes.first.type == :function &&
             %w[linear-gradient radial-gradient].include?(nodes.first.value)
          check_gradient(nodes, path)
        else
          check_color(nodes, path)
        end
      when :gradient
        check_gradient(nodes, path)
      when :border
        check_border(nodes, path)
      when :length
        check_length(nodes, path, *args, percent: property_percent(property, area))
      when :signed_length
        check_length(nodes, path, *args, allow_negative: true)
      when :length_list
        check_length_list(nodes, path, *args, percent: property_percent(property, area))
      when :keyword
        check_keyword(nodes, path, args.first)
      when :shadow
        check_shadow(nodes, path, max_offset: 20, max_blur: 40, max_spread: 20, max_layers: 2)
      when :text_shadow
        check_shadow(nodes, path, max_offset: 4, max_blur: 8, max_spread: nil, max_layers: 1)
      when :font_weight
        check_font_weight(nodes, path)
      when :font_family
        check_font_family(nodes, path)
      when :line_height
        check_line_height(nodes, path)
      when :number
        check_number(nodes, path, *args)
      when :transition
        check_transition(nodes, path)
      when :display
        if !area.hideable
          error(path, "#{area.label} cannot be hidden")
        elsif nodes.size != 1 || nodes.first.type != :ident || nodes.first.value != "none"
          error(path, "display only allows none")
        else
          true
        end
      end
    end

    # When a rule sets a background or a text color, check the text stays
    # readable in light and dark mode: against the rule's own background, or
    # the one core gives the area. Every color of a gradient is checked.
    # Translucent colors depend on what is behind them, so they aren't
    # checked; any other color the rule sets has to be one that can be.
    def readable?(declarations, path, area, state = nil)
      own_text = declarations["color"]
      text = own_text || area.text_color
      own_backgrounds = background_values(declarations)
      backgrounds = own_backgrounds
      if backgrounds.empty?
        return true if !own_text
        default = (state == "hover" && area.hover_background) || area.background
        backgrounds = CssValue.parse(default)
      end
      return true if !text

      %w[light dark].all? do |mode|
        text_hex = resolve_color(text, mode)
        next unreadable_unknown(path, "color") if text_hex.nil? && own_text
        next error(path, "text needs an opaque color") if text_hex == :translucent && own_text
        next true if !text_hex.is_a?(String)
        required = area.icon ? MINIMUM_ICON_CONTRAST : MINIMUM_CONTRAST

        backgrounds.all? do |background|
          own = own_backgrounds.include?(background)
          background_hex = shown_background(background, area, mode)
          next unreadable_unknown(path, "background") if background_hex.nil? && own
          next true if !background_hex.is_a?(String)

          ratio = contrast(text_hex, background_hex)
          next true if ratio >= required
          error(
            path,
            "text on background is #{ratio}:1 in #{mode} mode; it needs #{required}:1. Set a readable color too.",
          )
        end
      end
    end

    # Rules for the same area can apply at once, so each one's text is
    # checked against the other's background too: when their media and page
    # match or one has none, and their states match, one has none or one is
    # hover (a hovered row is also odd or even).
    def readable_together?
      @checked_rules
        .combination(2)
        .all? do |first, second|
          next true if first[:area] != second[:area] || !overlap?(first, second)

          state =
            (
              if [first[:state], second[:state]].include?("hover")
                "hover"
              else
                first[:state] || second[:state]
              end
            )
          path = "#{first[:path]} and #{second[:path]}"
          global_variables = @draft_variables
          @draft_variables = global_variables.merge(first[:overrides]).merge(second[:overrides])
          begin
            [[first, second], [second, first]].all? do |under, over|
              readable?(under[:declarations].merge(over[:declarations]), path, first[:area], state)
            end
          ensure
            @draft_variables = global_variables
          end
        end
    end

    # Text in an area shows on the background of the nearest area around it
    # that paints one, and may take its color from an area around it, so
    # rules on surrounding areas are checked with the text inside them.
    def readable_nested?
      rules_by_area = @checked_rules.group_by { |rule| rule[:area].key }
      @catalog.all.all? do |area|
        chain = @catalog.chain(area)
        outer = chain.drop(1)
        next true if outer.none? { |around| rules_by_area[around.key] }

        own_rules = rules_by_area[area.key] || []
        texts =
          own_rules.filter_map do |rule|
            [rule[:declarations]["color"], rule] if rule[:declarations]["color"]
          end
        if texts.empty?
          next true if area.text_color.nil?
          texts = [[area.text_color, nil]]
          inherited =
            area.inherits_color &&
              outer
                .lazy
                .map do |around|
                  (rules_by_area[around.key] || []).select { |rule| rule[:declarations]["color"] }
                end
                .find(&:any?)
          texts += inherited.map { |rule| [rule[:declarations]["color"], rule] } if inherited
        end

        backgrounds = nil
        chain.each do |node|
          painted =
            (rules_by_area[node.key] || []).flat_map do |rule|
              background_values(rule[:declarations]).map { |background| [background, rule] }
            end
          if painted.any?
            backgrounds = painted
            break
          end
          if node.paints_background
            backgrounds = CssValue.parse(node.background).map { |background| [background, nil] }
            break
          end
        end
        backgrounds ||=
          CssValue.parse(AreaCatalog::PAGE_BACKGROUND).map { |background| [background, nil] }

        texts.all? do |text, text_rule|
          backgrounds.all? do |background, background_rule|
            sources = [text_rule, background_rule].compact.uniq
            # a rule's own text on its own background was checked with the rule
            next true if sources.all? { |rule| rule[:area] == area }
            next true if sources.empty?

            readable_on?(text, background, area, sources.map { |rule| rule[:path] }.join(" and "))
          end
        end
      end
    end

    # Like variable pairs, AA or no worse than core's own default for the area,
    # which misses AA in places (category headings, links).
    def readable_on?(text, background, area, path)
      %w[light dark].all? do |mode|
        text_hex = resolve_color(text, mode)
        background_hex = shown_background(background, area, mode)
        next true if !text_hex.is_a?(String) || !background_hex.is_a?(String)

        required = area.icon ? MINIMUM_ICON_CONTRAST : MINIMUM_CONTRAST
        default_text = area.text_color && resolve_color(area.text_color, mode, use_draft: false)
        default_background = resolve_color(default_background(area), mode, use_draft: false)
        if default_text.is_a?(String) && default_background.is_a?(String)
          required = [required, contrast(default_text, default_background)].min
        end

        ratio = contrast(text_hex, background_hex)
        next true if ratio >= required
        error(
          path,
          "#{area.label} text is #{ratio}:1 on the background around it in #{mode} mode; it needs #{required}:1",
        )
      end
    end

    # The color a background shows: see-through ones are composited onto the
    # background core shows around the area. Returns nil when that can't be
    # told.
    def shown_background(node, area, mode, depth = 0)
      hex = resolve_node(node, mode)
      return hex if hex != :translucent || depth > 8

      behind = resolve_color(outside_background(area), mode)
      return if !behind.is_a?(String)

      case node.type
      when :ident
        behind if node.value.downcase == "transparent"
      when :function
        if node.value == "var"
          name = node.children.first&.value
          value = (@draft_variables || {})[name] || @registry[name]&.default
          nodes = value && CssValue.parse(value.to_s)
          nodes&.size == 1 ? shown_background(nodes.first, area, mode, depth + 1) : nil
        elsif (rgb = palette_rgb(node))
          name, opacity = rgb
          color = resolve_variable(name.delete_suffix("-rgb"), mode)
          blend(color, behind, opacity) if color.is_a?(String)
        end
      end
    rescue CssValue::ParseError
      nil
    end

    def blend(color, behind, opacity)
      ColorMath::Converters.rgb_to_hex(
        ColorMath::Converters
          .hex_to_rgb(color)
          .zip(ColorMath::Converters.hex_to_rgb(behind))
          .map { |front, back| ((front * opacity) + (back * (1 - opacity))).round },
      )
    end

    # The background around an area, outside it.
    def outside_background(area)
      painted = @catalog.chain(area).drop(1).find(&:paints_background)
      painted ? painted.background : AreaCatalog::PAGE_BACKGROUND
    end

    # The background core shows behind an area's text.
    def default_background(area)
      painted = @catalog.chain(area).find(&:paints_background)
      painted ? painted.background : AreaCatalog::PAGE_BACKGROUND
    end

    def overlap?(first, second)
      states = [first[:state], second[:state]]
      return false if states.compact.size == 2 && states.uniq.size == 2 && !states.include?("hover")

      %i[media page].all? { |key| first[key].nil? || second[key].nil? || first[key] == second[key] }
    end

    def unreadable_unknown(path, what)
      error(
        path,
        "can't tell how readable this #{what} is; use palette variables, color-mix() of them, or hex colors in light-dark()",
      )
    end

    # The colors a rule paints behind its text, as value nodes.
    def background_values(declarations)
      declarations
        .values_at("background-color", "background", "background-image")
        .compact
        .flat_map do |value|
          nodes = CssValue.parse(value.to_s)
          next [] if nodes.size != 1
          node = nodes.first
          if node.type == :function && %w[linear-gradient radial-gradient].include?(node.value)
            CssValue
              .split_commas(node.children)
              .filter_map do |part|
                colors =
                  part.reject do |n|
                    n.type == :dimension ||
                      (n.type == :ident && GRADIENT_KEYWORDS.include?(n.value))
                  end
                colors.first if colors.size == 1
              end
          else
            [node]
          end
        rescue CssValue::ParseError
          []
        end
    end

    # Backgrounds without a text variable of their own, with the text core
    # shows on them.
    BACKGROUND_TEXT = {
      "--d-badge-card-background-color" => "--primary",
      "--d-category-box-background-color" => "--primary",
      "--d-content-background" => "--primary",
      "--d-post-aside-background" => "--primary",
      "--d-sidebar-background" => "--d-sidebar-link-color",
      "--d-sidebar-highlight-hover-background" => "--d-sidebar-highlight-color",
      "--d-unread-notification-background" => "--primary",
      "--token-color-surface" => "--token-color-text-default",
      "--token-color-surface-hovered" => "--token-color-text-default",
      "--token-color-surface-pressed" => "--token-color-text-default",
      "--token-color-surface-focused" => "--token-color-text-default",
      "--token-color-surface-selected" => "--token-color-text-default",
    }.freeze

    # Background and text variables that render together, found by naming
    # convention (-bg-color, -background-color or -background with
    # -text-color or -color), plus the
    # backgrounds whose text is listed above.
    def variable_pairs
      @variable_pairs ||=
        begin
          pairs =
            @registry.all.flat_map do |variable|
              texts = [BACKGROUND_TEXT[variable.name]]
              match =
                variable.name.match(
                  /\A(.*?)(?:-bg-color|-background-color|-background)(--[a-z]+)?\z/,
                )
              if match
                base, state = match.captures
                named =
                  ["#{base}-text-color#{state}", "#{base}-color#{state}"].find do |name|
                    @registry[name]
                  end
                icon = "#{base}-icon-color#{state}"
                texts = [named || texts.first, (icon if @registry[icon])]
              end
              texts.compact.map { |text| [variable.name, text] }
            end
          paired = pairs.map(&:last)
          standalone =
            @registry.all.filter_map do |variable|
              next if !foreground?(variable) || paired.include?(variable.name)
              [foreground_background(variable.name), variable.name]
            end
          pairs + standalone
        end
    end

    # Color variables core uses for text or icons.
    def foreground?(variable)
      variable.type == "color" &&
        (
          variable.name.match?(/-color(--[a-z-]+)?\z/) ||
            variable.name.match?(/\A--token-color-(text|icon)-/)
        ) && !variable.name.match?(/background|-bg-|bg-color|border|shadow|outline|divider|fill/)
    end

    # The background a text or icon variable without a pair shows on.
    def foreground_background(name)
      case name
      when /\A--d-sidebar-/
        "--d-sidebar-background"
      when /\A--d-header-/
        "--header_background"
      when /\A--token-color-/
        "--token-color-surface"
      else
        "--secondary"
      end
    end

    # Text needs 4.5:1 and icons 3:1 (WCAG non-text contrast). Core's own
    # defaults miss 4.5:1 in places, so a pair passes when it is AA or at
    # least as readable as core's default.
    def readable_variables?(variables, path = "variables")
      variable_pairs.all? do |background, text|
        next true if !variables.key?(background) && !variables.key?(text)

        %w[light dark].all? do |mode|
          background_hex = resolve_variable(background, mode)
          text_hex = resolve_variable(text, mode)
          if background_hex.nil? && variables.key?(background)
            next unreadable_unknown(path, background)
          end
          next unreadable_unknown(path, text) if text_hex.nil? && variables.key?(text)
          if text_hex == :translucent && variables.key?(text)
            next error(path, "#{text}: text needs an opaque color")
          end
          next true if !background_hex.is_a?(String) || !text_hex.is_a?(String)

          ratio = contrast(text_hex, background_hex)
          required = text.include?("icon") ? MINIMUM_ICON_CONTRAST : MINIMUM_CONTRAST
          default_background = resolve_variable(background, mode, use_draft: false)
          default_text = resolve_variable(text, mode, use_draft: false)
          if default_background.is_a?(String) && default_text.is_a?(String)
            required = [required, contrast(default_text, default_background)].min
          end
          next true if ratio >= required
          error(
            path,
            "#{text} on #{background} is #{ratio}:1 in #{mode} mode; it needs #{required}:1",
          )
        end
      end
    end

    def contrast(color, other_color)
      ColorMath.contrast_ratio(color, other_color).floor(2)
    end

    def resolve_variable(name, mode, depth = 0, use_draft: true)
      return if depth > 8

      # a design variable a draft overrides wins, even when the palette also
      # defines it
      value = use_draft ? (@draft_variables || {})[name] : nil
      return resolve_color(value, mode, depth + 1, use_draft:) if value
      return @palette_colors[mode][name] if @registry.palette_variable?(name)

      value = @registry[name]&.default
      value && resolve_color(value, mode, depth + 1, use_draft:)
    end

    def resolve_color(value, mode, depth = 0, use_draft: true)
      nodes = CssValue.parse(value.to_s)
      return if nodes.size != 1
      resolve_node(nodes.first, mode, depth, use_draft:)
    rescue CssValue::ParseError
      nil
    end

    # Returns the hex color a value shows, :translucent when it depends on
    # what is behind it, or nil when it can't be told.
    def resolve_node(node, mode, depth = 0, use_draft: true)
      case node.type
      when :ident
        :translucent if node.value.downcase == "transparent"
      when :hash
        PaletteColors.normalize(node.value) if node.value.match?(/\A(\h{3}|\h{6})\z/)
      when :function
        case node.value
        when "var"
          name = node.children.first&.value
          resolve_variable(name, mode, depth + 1, use_draft:) if name
        when "light-dark"
          part = CssValue.split_commas(node.children)[mode == "light" ? 0 : 1]
          part&.size == 1 ? resolve_node(part.first, mode, depth, use_draft:) : nil
        when "color-mix"
          resolve_mix(node, mode, depth, use_draft:)
        when "rgb", "rgba"
          resolve_rgb(node, mode, depth, use_draft:)
        end
      end
    end

    # color-mix(in srgb, A p%, B q%), the only color space mixed here.
    def resolve_mix(node, mode, depth, use_draft:)
      space, *parts = CssValue.split_commas(node.children)
      return if space.map { |n| n.value.to_s.downcase } != %w[in srgb] || parts.size != 2

      colors =
        parts.map do |part|
          color = part.find { |n| n.type != :dimension }
          percent = part.find { |n| n.type == :dimension && n.unit == "%" }&.value
          [color && resolve_node(color, mode, depth + 1, use_draft:), percent]
        end
      return if colors.any? { |hex, _| hex.nil? }
      return :translucent if colors.any? { |hex, _| hex == :translucent }

      (first, first_percent), (second, second_percent) = colors
      first_percent ||= second_percent ? 100 - second_percent : 50
      second_percent ||= 100 - first_percent
      total = first_percent + second_percent
      return if total <= 0 || total > 100
      # percentages under 100% leave the mix partly transparent
      return :translucent if total < 100

      weight = first_percent / total.to_f
      ColorMath::Converters.rgb_to_hex(
        ColorMath::Converters
          .hex_to_rgb(first)
          .zip(ColorMath::Converters.hex_to_rgb(second))
          .map { |a, b| ((a * weight) + (b * (1 - weight))).round },
      )
    end

    # rgb(var(--name-rgb)) with an optional alpha, as either syntax allows.
    def resolve_rgb(node, mode, depth, use_draft:)
      name, opacity = palette_rgb(node)
      return if name.nil?
      return :translucent if opacity < 1
      resolve_variable(name.delete_suffix("-rgb"), mode, depth + 1, use_draft:)
    end

    # The palette variable and opacity of rgb(var(--name-rgb)),
    # rgba(var(--name-rgb), 0.1) or rgb(var(--name-rgb) / 10%), or nil.
    def palette_rgb(node)
      return if !%w[rgb rgba].include?(node.value)

      parts = CssValue.split_commas(node.children)
      slash = node.children.index { |n| n.type == :delim && n.value == "/" }
      color, alpha =
        if parts.size == 1 && slash
          [node.children[0...slash], node.children[(slash + 1)..]]
        elsif parts.size <= 2
          parts
        end
      return if color&.size != 1 || color.first.type != :function || color.first.value != "var"
      name = color.first.children.first&.value.to_s
      return if !name.end_with?("-rgb") || !@registry.palette_variable?(name)

      opacity = 1
      if alpha
        return if alpha.size != 1
        value = alpha.first
        opacity =
          if value.type == :dimension && value.unit == "%"
            value.value / 100.0
          elsif value.type == :number
            value.value
          end
        return if opacity.nil? || opacity.negative? || opacity > 1
      end
      [name, opacity]
    end

    # The palettes styles are checked against, or core's light and dark ones.
    def palette_colors(palettes)
      {
        "light" => PaletteColors.new(palettes&.dig("light") || ColorScheme.base_colors),
        "dark" => PaletteColors.new(palettes&.dig("dark") || ColorScheme::BUILT_IN_SCHEMES[:Dark]),
      }
    end

    def parse(value, path)
      return error(path, "value must be a string") if !value.is_a?(String) && !value.is_a?(Numeric)
      value = value.to_s.strip
      return error(path, "value is empty") if value.empty?
      return error(path, "value is too long") if value.length > MAX_VALUE_LENGTH

      bad_char = FORBIDDEN_CHARACTERS.find { |char| value.include?(char) }
      return error(path, "character #{bad_char.inspect} is not allowed") if bad_char
      lowered = value.downcase
      bad = FORBIDDEN_SUBSTRINGS.find { |substring| lowered.include?(substring) }
      return error(path, "#{bad.inspect} is not allowed") if bad

      nodes = CssValue.parse(value)
      return if !check_tree(nodes, path)
      nodes
    rescue CssValue::ParseError => e
      error(path, e.message)
    end

    # Structural checks that apply to every value: known functions, var()
    # only pointing at palette or design variables, sane delimiters.
    def check_tree(nodes, path)
      ok = true
      CssValue.each_node(nodes) do |node|
        case node.type
        when :function
          if !ALLOWED_FUNCTIONS.include?(node.value)
            ok = error(path, "#{node.value}() is not allowed")
          elsif node.value == "var"
            name = node.children.first
            if name&.type != :ident || !@registry.referenceable?(name.value)
              ok = error(path, "var() must reference a palette or design variable")
            elsif node.children.size != 1
              # Every referenceable variable is always defined, so a fallback
              # could only smuggle in a value that skips the checks.
              ok = error(path, "var() fallbacks are not allowed")
            end
          end
        when :delim
          ok = error(path, "#{node.value.inspect} is not allowed") if !%w[+ - * /].include?(
            node.value,
          )
        when :dimension
          unit = node.unit
          if !LENGTH_UNITS.include?(unit) && !%w[deg s ms].include?(unit)
            ok = error(path, "unit #{unit} is not allowed")
          end
        end
      end
      ok
    end

    # A color must follow the active palette: palette variables, mixes of
    # them, or raw colors only inside light-dark(light, dark).
    def check_color(nodes, path)
      return error(path, "expected a single color") if nodes.size != 1
      color_expression?(nodes.first, path, inside_light_dark: false)
    end

    def color_expression?(node, path, inside_light_dark:)
      case node.type
      when :ident
        return true if COLOR_KEYWORDS.include?(node.value.downcase) && !inside_light_dark
        return error(path, "light-dark() takes hex colors") if inside_light_dark
        error(path, "#{node.value} is not a palette color; use var(--...) or light-dark()")
      when :hash
        return true if inside_light_dark
        error(path, "raw color ##{node.value} must be inside light-dark(light, dark)")
      when :function
        case node.value
        when "var"
          true
        when "light-dark"
          parts = CssValue.split_commas(node.children)
          return error(path, "light-dark() needs two colors") if parts.size != 2
          parts.all? do |part|
            part.size == 1 && color_expression?(part.first, path, inside_light_dark: true)
          end
        when "color-mix"
          parts = CssValue.split_commas(node.children)
          return error(path, "color-mix() needs a space and two colors") if parts.size != 3
          parts
            .drop(1)
            .all? do |part|
              colors = part.reject { |n| n.type == :dimension && n.unit == "%" }
              colors.size == 1 && color_expression?(colors.first, path, inside_light_dark:)
            end
        when *RAW_COLOR_FUNCTIONS
          return error(path, "light-dark() takes hex colors") if inside_light_dark
          return true if palette_rgb?(node)
          error(
            path,
            "raw color #{node.value}() must use a palette variable, as rgb(var(--primary-rgb)) or rgba(var(--primary-rgb), 0.1), or be hex inside light-dark()",
          )
        else
          error(path, "#{node.value}() is not a color")
        end
      else
        error(path, "expected a color")
      end
    end

    def palette_rgb?(node)
      !palette_rgb(node).nil?
    end

    def check_gradient(nodes, path)
      if nodes.size != 1 || nodes.first.type != :function ||
           !%w[linear-gradient radial-gradient].include?(nodes.first.value)
        return error(path, "expected linear-gradient() or radial-gradient()")
      end
      parts = CssValue.split_commas(nodes.first.children)
      return error(path, "gradients allow at most 4 parts") if parts.size > 4
      stops = 0
      parts.each_with_index do |part, index|
        colors =
          part.reject do |n|
            (n.type == :dimension && (LENGTH_UNITS.include?(n.unit) || n.unit == "deg")) ||
              (n.type == :ident && GRADIENT_KEYWORDS.include?(n.value.downcase))
          end
        if colors.empty? && index.zero?
          next
        elsif colors.size == 1 && color_expression?(colors.first, path, inside_light_dark: false)
          stops += 1
        else
          return error(path, "invalid gradient part")
        end
      end
      stops >= 2 ? true : error(path, "gradients need at least two colors")
    end

    def to_px(node)
      case node.unit
      when "px"
        node.value
      when "rem", "em"
        node.value * 16
      end
    end

    # What a percentage means for a length: a share of the font size, a share
    # of the element or its container that can't exceed it, or nothing that
    # can be bounded.
    def property_percent(property, area)
      if property == "font-size"
        :font
      elsif property == "border-radius" || (area.sizeable && SIZE_PROPERTIES.include?(property))
        :share
      end
    end

    def length_percent(variable_name)
      if variable_name.match?(/font-size|header-size/)
        :font
      elsif variable_name.include?("radius")
        :share
      end
    end

    def check_length(nodes, path, min_px, max_px, allow_negative: false, percent: nil)
      return error(path, "expected a single length") if nodes.size != 1
      length_ok?(nodes.first, path, min_px, max_px, allow_negative:, percent:)
    end

    # Checks the length a value works out to, so calc(), var() and zero are
    # bounded like any other length. Values whose size can't be known, such
    # as percentages inside calc(), are rejected.
    def length_ok?(node, path, min_px, max_px, allow_negative: false, percent: nil)
      if node.type == :dimension && node.unit == "%"
        case percent
        when :share
          return true if node.value.between?(0, 100)
          return error(path, "percentage must be between 0 and 100")
        when :font
          px = node.value * 16 / 100.0
        else
          return error(path, "percentages aren't allowed here")
        end
      else
        px = length_px(node)
      end

      return error(path, "negative values are not allowed") if px.negative? && !allow_negative
      return true if px.round(2).between?(min_px, max_px)
      error(
        path,
        "#{describe_length(node)} is #{px.round(1)}px, outside #{min_px}px to #{max_px}px",
      )
    rescue UnknownLength => e
      error(path, e.message)
    end

    class UnknownLength < StandardError
    end

    # core's spacing scale is multiples of 4px, and its font scale steps by
    # 2^(1/5) from 1em
    SPACE_PX = 4

    def length_px(node, depth = 0)
      value, unit = evaluate_length(node, depth)
      raise UnknownLength, "expected a length" if unit != :px && !(unit == :number && value.zero?)
      value.to_f
    end

    # Returns [value, :px] or [value, :number].
    def evaluate_length(node, depth)
      raise UnknownLength, "the length can't be known" if depth > 8

      case node.type
      when :number
        [node.value, :number]
      when :dimension
        px = to_px(node)
        raise UnknownLength, "the length can't be known with #{node.unit}" if px.nil?
        [px, :px]
      when :group
        evaluate_expression(node.children, depth + 1)
      when :function
        case node.value
        when "var"
          [variable_length_px(node.children.first&.value, depth + 1), :px]
        when "calc"
          evaluate_expression(node.children, depth + 1)
        when "min", "max", "clamp"
          values =
            CssValue.split_commas(node.children).map { |part| evaluate_expression(part, depth + 1) }
          if values.empty? || values.map(&:last).uniq.size != 1 ||
               (node.value == "clamp" && values.size != 3)
            raise UnknownLength, "#{node.value}() needs matching lengths"
          end
          numbers = values.map(&:first)
          value =
            case node.value
            when "min"
              numbers.min
            when "max"
              numbers.max
            else
              numbers[1].clamp(numbers[0], [numbers[0], numbers[2]].max)
            end
          [value, values.first.last]
        else
          raise UnknownLength, "#{node.value}() is not a length"
        end
      else
        raise UnknownLength, "expected a length"
      end
    end

    def evaluate_expression(nodes, depth)
      terms = [[]]
      operators = []
      nodes.each do |node|
        if node.type == :delim && %w[+ -].include?(node.value)
          operators << node.value
          terms << []
        else
          terms.last << node
        end
      end

      values = terms.map { |term| evaluate_term(term, depth) }
      values
        .drop(1)
        .zip(operators)
        .reduce(values.first) do |(total, unit), ((value, other_unit), operator)|
          raise UnknownLength, "can't add a length and a number" if unit != other_unit
          [operator == "+" ? total + value : total - value, unit]
        end
    end

    def evaluate_term(nodes, depth)
      if nodes.empty? || nodes.size.even?
        raise UnknownLength, "the length can't be known from this expression"
      end

      operands = nodes.each_slice(2).map(&:first)
      operators = nodes.each_slice(2).filter_map { |_, operator| operator }
      if operators.any? { |operator| operator.type != :delim || !%w[* /].include?(operator.value) }
        raise UnknownLength, "the length can't be known from this expression"
      end

      values = operands.map { |operand| evaluate_length(operand, depth) }
      values
        .drop(1)
        .zip(operators)
        .reduce(values.first) { |result, (value, operator)| apply(result, operator.value, value) }
    end

    def apply((value, unit), operator, (other, other_unit))
      if operator == "*"
        raise UnknownLength, "can't multiply two lengths" if unit == :px && other_unit == :px
        [value * other, unit == :px || other_unit == :px ? :px : :number]
      else
        if other_unit != :number || other.zero?
          raise UnknownLength, "can only divide by a number other than 0"
        end
        [value / other.to_f, unit]
      end
    end

    # The pixels a length variable works out to: core's spacing and font
    # scales, or a design variable's value in this draft or by default.
    def variable_length_px(name, depth)
      raise UnknownLength, "the length can't be known" if name.nil? || depth > 8

      if name == "--space"
        SPACE_PX
      elsif (match = name.match(/\A--space-(\d+|half)\z/))
        match[1] == "half" ? SPACE_PX / 2.0 : SPACE_PX * match[1].to_i
      elsif name.match?(/\A--font-0(-rem)?\z/)
        16
      elsif (match = name.match(/\A--font-(up|down)-(\d+)(-rem)?\z/))
        steps = match[2].to_i * (match[1] == "up" ? 1 : -1)
        16 * (2**(steps / 5.0))
      else
        variable = @registry[name]
        if variable&.type != "length"
          raise UnknownLength, "var(#{name}) is not a length that can be known"
        end
        value = (@draft_variables || {})[name] || variable.default
        nodes = CssValue.parse(value.to_s)
        raise UnknownLength, "var(#{name}) is not a length that can be known" if nodes.size != 1
        length_px(nodes.first, depth + 1)
      end
    rescue CssValue::ParseError
      raise UnknownLength, "var(#{name}) is not a length that can be known"
    end

    def describe_length(node)
      node.type == :dimension ? "#{node.value}#{node.unit}" : "the value"
    end

    def check_length_list(nodes, path, min_px, max_px, percent: nil)
      return error(path, "expected 1 to 4 lengths") if nodes.empty? || nodes.size > 4
      nodes.all? { |node| length_ok?(node, path, min_px, max_px, percent:) }
    end

    def check_keyword(nodes, path, keywords)
      if nodes.size == 1 && nodes.first.type == :ident &&
           keywords.include?(nodes.first.value.downcase)
        true
      else
        error(path, "expected one of #{keywords.join(", ")}")
      end
    end

    def check_border(nodes, path)
      return error(path, "expected width, style and color") if nodes.empty? || nodes.size > 3
      widths = nodes.select { |n| n.type == :dimension || (n.type == :number && n.value.zero?) }
      styles =
        nodes.select { |n| n.type == :ident && %w[solid dashed dotted none].include?(n.value) }
      colors = nodes - widths - styles
      return error(path, "border needs a style") if styles.size != 1
      if widths.size > 1 || colors.size > 1
        return error(path, "border allows one width and one color")
      end
      widths.all? { |n| length_ok?(n, path, 0, 8) } &&
        colors.all? { |n| color_expression?(n, path, inside_light_dark: false) }
    end

    def check_shadow(nodes, path, max_offset:, max_blur:, max_spread:, max_layers:)
      return true if nodes.size == 1 && nodes.first.type == :ident && nodes.first.value == "none"
      layers = CssValue.split_commas(nodes)
      return error(path, "at most #{max_layers} shadow(s)") if layers.size > max_layers
      layers.all? do |layer|
        layer = layer.reject { |n| n.type == :ident && n.value == "inset" && max_spread }
        lengths = layer.select { |n| n.type == :dimension || n.type == :number }
        colors = layer - lengths
        max_lengths = max_spread ? 4 : 3
        if !lengths.size.between?(2, max_lengths)
          next error(path, "shadow needs 2 to #{max_lengths} lengths")
        end
        next error(path, "shadow allows one color") if colors.size > 1
        bounds = [max_offset, max_offset, max_blur, max_spread]
        lengths.each_with_index.all? do |node, index|
          limit = bounds[index]
          min = index < 2 || index == 3 ? -limit : 0
          length_ok?(node, path, min, limit, allow_negative: true)
        end && colors.all? { |n| color_expression?(n, path, inside_light_dark: false) }
      end
    end

    def check_font_weight(nodes, path)
      return error(path, "expected a font weight") if nodes.size != 1
      node = nodes.first
      case node.type
      when :number
        node.value.between?(100, 900) ? true : error(path, "font weight must be 100 to 900")
      when :ident
        %w[normal bold].include?(node.value) ? true : error(path, "expected normal or bold")
      when :function
        node.value == "var" ? true : error(path, "expected a font weight")
      else
        error(path, "expected a font weight")
      end
    end

    def check_font_family(nodes, path)
      ok =
        nodes.size == 1 && nodes.first.type == :function && nodes.first.value == "var" &&
          %w[--font-family --heading-font-family].include?(nodes.first.children.first&.value)
      if ok
        true
      else
        error(
          path,
          "fonts are chosen with the font settings; use var(--font-family) or var(--heading-font-family)",
        )
      end
    end

    def check_line_height(nodes, path)
      return error(path, "expected a line height") if nodes.size != 1
      node = nodes.first
      return true if node.type == :ident && node.value == "normal"
      if node.type == :number
        return(node.value.between?(1, 2.5) ? true : error(path, "line height must be 1 to 2.5"))
      end
      length_ok?(node, path, 12, 48)
    end

    def check_number(nodes, path, min, max)
      if nodes.size == 1 && nodes.first.type == :number && nodes.first.value.between?(min, max)
        true
      else
        error(path, "expected a number from #{min} to #{max}")
      end
    end

    def check_transition(nodes, path)
      return true if nodes.size == 1 && nodes.first.type == :ident && nodes.first.value == "none"
      parts = CssValue.split_commas(nodes)
      return error(path, "at most 3 transitions") if parts.size > 3
      parts.all? do |part|
        property = part.find { |n| n.type == :ident && !EASINGS.include?(n.value) }
        duration = part.find { |n| n.type == :dimension && %w[s ms].include?(n.unit) }
        rest = part - [property, duration].compact
        if !property || !TRANSITION_PROPERTIES.include?(property.value)
          next error(path, "transitions are limited to #{TRANSITION_PROPERTIES.join(", ")}")
        end
        ms = duration && (duration.unit == "s" ? duration.value * 1000 : duration.value)
        next error(path, "transition duration must be up to 300ms") if !ms || !ms.between?(0, 300)
        if rest.any? { |n| !(n.type == :ident && EASINGS.include?(n.value)) }
          next error(path, "unexpected transition value")
        end
        true
      end
    end
  end
end
