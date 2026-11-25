# frozen_string_literal: true

# Checks typed theme styles and writes the CSS for them, so styles that come
# from somewhere untrusted (a language model, an import) can only make
# cosmetic changes. Styles never contain CSS text or selectors:
#
#   {
#     "variables" => { "--d-sys-border-radius-md" => "12px" },
#     "rules" => [
#       { "area" => "topic_list_item", "state" => "hover", "media" => "desktop",
#         "declarations" => { "box-shadow" => "0 2px 8px color-mix(in srgb, var(--primary) 8%, transparent)" } }
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
    # failures reported for one area at a time
    MAX_ERRORS_PER_AREA = 4
    MAX_VALUE_LENGTH = 200
    MAX_CSS_BYTES = 16 * 1024

    # Never style the admin area, so an admin can always get back to
    # Customize > Themes. Variables go on the root element because derived
    # variables (e.g. --d-comp-DButton-border-radius: var(--d-sys-border-radius-md)) are
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
    def self.call(styles, palettes: nil, base_theme_id: nil)
      new(
        styles,
        registry: VariableRegistry.instance,
        catalog: AreaCatalog.instance,
        palettes:,
        base_theme_id:,
      ).call
    end

    def initialize(styles, registry:, catalog:, palettes: nil, base_theme_id: nil)
      @horizon = base_theme_id == Theme::CORE_THEMES["horizon"]
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
      @global_variables = variables
      errors_before_rules = @errors.size
      rules.each_with_index { |rule, index| blocks.concat(check_rule(rule, "rules[#{index}]")) }
      # rules are checked together once each one is valid on its own
      readable_everywhere? if @errors.size == errors_before_rules

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

      if @horizon && !%w[length keyword font_weight].include?(variable.type)
        return horizon_color_error(path)
      end

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
      return [] if !measurable?(declarations, path)
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

    def horizon_color_error(path)
      error(
        path,
        "styles on Horizon can't set colors yet, since their contrast can't be checked on Horizon; change colors with palettes instead",
      )
    end

    def check_property(property, value, path, area)
      if @horizon &&
           (
             COLOR_PROPERTIES.include?(property) ||
               %w[
                 background
                 background-image
                 border
                 border-top
                 border-right
                 border-bottom
                 border-left
                 box-shadow
                 text-shadow
                 opacity
               ].include?(property)
           )
        return horizon_color_error(path)
      end
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

    # A rule's own colors have to be ones whose contrast can be measured, and
    # its text has to be opaque. How readable they are, with everything else
    # that can apply at the same time, is checked by readable_everywhere?.
    def measurable?(declarations, path)
      own_text = declarations["color"]
      own_backgrounds = background_values(declarations)

      %w[light dark].all? do |mode|
        if own_text
          text_hex = resolve_color(own_text, mode)
          next unreadable_unknown(path, "color") if text_hex.nil?
          next error(path, "text needs an opaque color") if text_hex == :translucent
        end
        own_backgrounds.all? do |background|
          color_with_alpha(background, mode) ? true : unreadable_unknown(path, "background")
        end
      end
    end

    BACKGROUND_PROPERTIES = %w[background-color background background-image].freeze

    # One combination of the conditions rules can depend on: the screen, the
    # page, which of an area's elements are hovered (by level, see
    # #readable_area?) and whether each is an odd or even row.
    Situation = Data.define(:media, :page, :hovered, :parity)

    # Checks the text of every area against its background in every situation
    # a rule can apply in, with the declarations that would actually win
    # there: rules for the area, for areas that style the same element, and
    # for the areas around it, which paint the background behind it and may
    # give it its color.
    def readable_everywhere?
      rules =
        @checked_rules.each_with_index.map do |rule, index|
          rule.merge(index:, specificity: specificity(rule))
        end
      # every area is checked, so all of them can be fixed at once
      @catalog.all.map { |area| readable_area?(area, rules) }.all?
    end

    # Level 0 is the area's own element, which the areas it shares an element
    # with also style; the levels after it are the areas around it,
    # innermost first.
    def readable_area?(area, rules)
      levels =
        @catalog.chain(area).map { |node| [node, *node.same_element.map { |key| @catalog[key] }] }
      level_rules = levels.map { |nodes| rules.select { |rule| nodes.include?(rule[:area]) } }
      return true if level_rules.all?(&:empty?)

      # every situation and mode is checked, so the author hears about all of
      # them at once; the same failure in several situations is reported once
      first_error = @errors.size
      readable =
        situations(levels, level_rules)
          .map { |situation| readable_in?(area, levels, level_rules, situation) }
          .all?
      area_errors = @errors.slice!(first_error..).uniq.first(MAX_ERRORS_PER_AREA)
      @errors.concat(area_errors)
      readable
    end

    def situations(levels, level_rules)
      rules = level_rules.flatten
      medias = rules.any? { |rule| rule[:media] } ? MEDIA.keys : [nil]
      pages = rules.any? { |rule| rule[:page] } ? [nil, *PAGES.keys] : [nil]
      hoverable =
        levels.each_index.select do |level|
          level_rules[level].any? { |rule| rule[:state] == "hover" } ||
            levels[level].first.hover_background
        end
      # hovering an element hovers the elements around it too
      hovers = (0..levels.size).map { |from| hoverable.select { |level| level >= from } }.uniq
      parities =
        level_rules.map do |rules_here|
          rules_here.any? { |rule| %w[odd even].include?(rule[:state]) } ? %w[odd even] : [nil]
        end
      parity_sets = parities.first.product(*parities.drop(1))

      medias
        .product(pages, hovers, parity_sets)
        .map { |media, page, hovered, parity| Situation.new(media:, page:, hovered:, parity:) }
    end

    def applies?(rule, level, situation)
      return false if rule[:media] && rule[:media] != situation.media
      return false if rule[:page] && rule[:page] != situation.page

      case rule[:state]
      when nil
        true
      when "hover"
        situation.hovered.include?(level)
      else
        situation.parity[level] == rule[:state]
      end
    end

    # For each level, the rule whose value wins for each property: the more
    # specific selector, then the later rule, as in the CSS written for them.
    def winning_rules(level_rules, situation)
      level_rules.each_with_index.map do |rules, level|
        rules
          .select { |rule| applies?(rule, level, situation) }
          .sort_by { |rule| [rule[:specificity], rule[:index]] }
          .each_with_object({}) do |rule, winners|
            rule[:declarations].each_key { |property| winners[property] = rule }
          end
      end
    end

    def specificity(rule)
      selector = scope_selector(rule[:area].selector, rule[:state], rule[:page]).split(",").first
      [
        selector.scan(/#[\w-]+/).size,
        selector.scan(/\.[\w-]+|:[\w-]+|\[/).size,
        selector.split(/[\s>+~]+/).count { |part| part.match?(/\A[a-z]/i) },
      ]
    end

    # The variables an element sees: the draft's, then those rules set on the
    # areas around it, then its own.
    def variables_at(winners, level)
      winners[level..]
        .reverse
        .each_with_object(@global_variables.dup) do |rules, variables|
          rules.each do |property, rule|
            variables[property] = rule[:declarations][property] if property.start_with?("--")
          end
        end
    end

    def variable_rules_at(winners, level)
      winners[level..]
        .flat_map do |rules|
          rules.filter_map { |property, rule| rule if property.start_with?("--") }
        end
        .uniq
    end

    def with_variables(variables)
      saved = @draft_variables
      @draft_variables = variables
      yield
    ensure
      @draft_variables = saved
    end

    # The text color an area shows, and the level of the rule it comes from:
    # its own, or, when core doesn't color it, the nearest area around it
    # that a rule gives a color, up to one core colors itself.
    def shown_text_color(area, levels, winners)
      if (rule = winners[0]["color"])
        return rule[:declarations]["color"], 0
      end
      if area.inherits_color
        (1...levels.size).each do |level|
          if (rule = winners[level]["color"])
            return rule[:declarations]["color"], level
          end
          node = levels[level].first
          break if !node.inherits_color && node.text_color
        end
      end
      [area.text_color, nil]
    end

    # The colors shown behind an element's text, each with the rules it comes
    # from: what the element paints, or what shows through from the areas
    # around it, see-through colors composited onto them.
    def backgrounds(levels, winners, situation, level, mode)
      if level >= levels.size
        return [[resolve_color(AreaCatalog::PAGE_BACKGROUND, mode), [], levels.size]]
      end

      painted = winners[level].slice(*BACKGROUND_PROPERTIES)
      node = levels[level].first
      if painted.empty?
        return backgrounds(levels, winners, situation, level + 1, mode) if !node.paints_background
        values =
          CssValue.parse(
            (situation.hovered.include?(level) && node.hover_background) || node.background,
          )
        sources = []
      else
        declarations = painted.to_h { |property, rule| [property, rule[:declarations][property]] }
        values = background_values(declarations)
        sources = painted.values.uniq
      end

      colors =
        with_variables(variables_at(winners, level)) do
          values.filter_map { |value| color_with_alpha(value, mode) }
        end
      colors.flat_map do |color, alpha|
        next [[color, sources, level]] if alpha >= 1

        backgrounds(
          levels,
          winners,
          situation,
          level + 1,
          mode,
        ).filter_map do |behind, behind_sources|
          [blend(color, behind, alpha), sources + behind_sources, level] if behind.is_a?(String)
        end
      end
    end

    def readable_in?(area, levels, level_rules, situation)
      winners = winning_rules(level_rules, situation)
      text, text_level = shown_text_color(area, levels, winners)
      return true if text.nil?

      text_rule = text_level && winners[text_level]["color"]
      variable_rules = variable_rules_at(winners, 0)
      element_variables = variables_at(winners, 0)

      # variables set by several rules that apply together
      if variable_rules.size > 1
        overrides =
          variable_rules.reduce({}) do |merged, rule|
            merged.merge(rule[:declarations].select { |property, _| property.start_with?("--") })
          end
        path =
          variable_rules.sort_by { |rule| rule[:index] }.map { |rule| rule[:path] }.join(" and ")
        return false if !with_variables(element_variables) { readable_variables?(overrides, path) }
      end

      %w[light dark]
        .map do |mode|
          text_hex = with_variables(element_variables) { resolve_color(text, mode) }
          next true if !text_hex.is_a?(String)

          backgrounds(
            levels,
            winners,
            situation,
            0,
            mode,
          ).all? do |background, background_rules, painted_at|
            next true if !background.is_a?(String)

            faded(
              levels,
              winners,
              situation,
              mode,
              text_hex,
              background,
              painted_at,
            ).all? do |shown_text, shown_background, opacity_rules|
              literal_rules = [text_rule, *background_rules, *opacity_rules].compact.uniq
              next true if literal_rules.empty? && variable_rules.empty?

              readable_pair?(
                area,
                shown_text,
                shown_background,
                mode,
                situation,
                literal_rules:,
                variable_rules:,
                own_element: levels.first,
              )
            end
          end
        end
        .all?
    end

    # A draft's own colors for an element are held to AA. Anything it shows
    # from the areas around it, or through variables, is held to AA or no
    # worse than core's default for the area, which misses AA in places
    # (category headings, links).
    def readable_pair?(
      area,
      text_hex,
      background,
      mode,
      situation,
      literal_rules:,
      variable_rules:,
      own_element:
    )
      strict = literal_rules.any? && literal_rules.all? { |rule| own_element.include?(rule[:area]) }
      required = area.icon ? MINIMUM_ICON_CONTRAST : MINIMUM_CONTRAST
      if !strict
        default_text = area.text_color && resolve_color(area.text_color, mode, use_draft: false)
        default_background = resolve_color(default_background(area), mode, use_draft: false)
        if default_text.is_a?(String) && default_background.is_a?(String)
          required = [required, contrast(default_text, default_background)].min
        end
      end

      ratio = contrast(text_hex, background)
      return true if ratio >= required

      path =
        (literal_rules.presence || variable_rules)
          .sort_by { |rule| rule[:index] }
          .map { |rule| rule[:path] }
          .join(" and ")
      where = describe(situation)
      if strict
        error(
          path,
          "text on background is #{ratio}:1 in #{mode} mode#{where}; it needs #{required}:1 (text ##{text_hex}, background ##{background}). Set a readable color too.",
        )
      else
        error(
          path,
          "#{area.label} text is #{ratio}:1 on the background around it in #{mode} mode#{where}; it needs #{required}:1 (text ##{text_hex}, background ##{background}). Set a readable color in a rule for the #{area.key} area too.",
        )
      end
    end

    # Text and background as they show once the opacity rules give an element
    # or the areas around it is applied: everything inside a faded element,
    # its own background too, is blended with what shows behind it.
    def faded(levels, winners, situation, mode, text, background, painted_at)
      shown = [[text, background, []]]
      levels.each_index do |level|
        rule = winners[level]["opacity"]
        next if rule.nil?
        opacity = rule[:declarations]["opacity"].to_s.to_f
        next if opacity >= 1

        behinds = backgrounds(levels, winners, situation, level + 1, mode)
        shown =
          shown.flat_map do |shown_text, shown_background, rules|
            behinds.filter_map do |behind, _, _|
              next if !behind.is_a?(String)
              [
                blend(shown_text, behind, opacity),
                painted_at <= level ? blend(shown_background, behind, opacity) : shown_background,
                rules + [rule],
              ]
            end
          end
      end
      shown
    end

    def describe(situation)
      parts = []
      parts << "on #{situation.media}" if situation.media
      parts << "on #{situation.page} pages" if situation.page
      parts << "on hover" if situation.hovered.include?(0)
      parts << "in #{situation.parity[0]} rows" if situation.parity[0]
      parts.empty? ? "" : " #{parts.join(", ")}"
    end

    # The color a background shows: see-through ones are composited onto the
    # background core shows around the area, or onto `behind` when there's no
    # area. Returns nil when that can't be told.
    def shown_background(node, area, mode, behind: nil, use_draft: true)
      color, alpha = color_with_alpha(node, mode, use_draft:)
      return if color.nil?
      return color if alpha >= 1

      behind_hex = resolve_color(behind || outside_background(area), mode, use_draft:)
      blend(color, behind_hex, alpha) if behind_hex.is_a?(String)
    end

    # A color as [hex, alpha], or nil when it can't be told. transparent,
    # rgb(var(--name-rgb), alpha), and color-mix() with a see-through color or
    # percentages under 100% are see-through.
    def color_with_alpha(node, mode, depth = 0, use_draft: true)
      return if depth > 8

      case node.type
      when :ident
        return "000000", 0.0 if node.value.downcase == "transparent"
      when :function
        case node.value
        when "var"
          return variable_with_alpha(node.children.first&.value, mode, depth, use_draft:)
        when "light-dark"
          part = CssValue.split_commas(node.children)[mode == "light" ? 0 : 1]
          return part&.size == 1 ? color_with_alpha(part.first, mode, depth + 1, use_draft:) : nil
        when "rgb", "rgba"
          name, opacity = palette_rgb(node)
          return if name.nil?
          hex = resolve_variable(name.delete_suffix("-rgb"), mode, use_draft:)
          return hex.is_a?(String) ? [hex, opacity.to_f] : nil
        when "color-mix"
          return mix_with_alpha(node, mode, depth, use_draft:)
        end
      end
      hex = resolve_node(node, mode, depth, use_draft:)
      hex.is_a?(String) ? [hex, 1.0] : nil
    rescue CssValue::ParseError
      nil
    end

    # Like resolve_variable: a draft's value wins over the palette's.
    def variable_with_alpha(name, mode, depth, use_draft:)
      return if name.nil?

      value = use_draft ? (@draft_variables || {})[name] : nil
      if value.nil? && @registry.palette_variable?(name)
        hex = @palette_colors[mode][name]
        return hex.is_a?(String) ? [hex, 1.0] : nil
      end
      value ||= @registry[name]&.default
      nodes = value && CssValue.parse(value.to_s)
      nodes&.size == 1 ? color_with_alpha(nodes.first, mode, depth + 1, use_draft:) : nil
    end

    # color-mix(in srgb, A p%, B q%) as [hex, alpha]: each color counts by its
    # weight and opacity, and percentages under 100% lower the opacity.
    def mix_with_alpha(node, mode, depth, use_draft:)
      space, *parts = CssValue.split_commas(node.children)
      return if space.map { |n| n.value.to_s.downcase } != %w[in srgb] || parts.size != 2

      colors =
        parts.map do |part|
          color = part.find { |n| n.type != :dimension }
          percent = part.find { |n| n.type == :dimension && n.unit == "%" }&.value
          [color && color_with_alpha(color, mode, depth + 1, use_draft:), percent]
        end
      return if colors.any? { |color, _| color.nil? }
      return if colors.any? { |_, percent| percent && !percent.between?(0, 100) }

      (first, first_percent), (second, second_percent) = colors
      first_percent ||= second_percent ? 100 - second_percent : 50
      second_percent ||= 100 - first_percent
      return if first_percent + second_percent > 100

      weighted = [[first, first_percent / 100.0], [second, second_percent / 100.0]]
      alpha = weighted.sum { |(_, color_alpha), weight| color_alpha * weight }
      return "000000", 0.0 if alpha <= 0

      rgb =
        weighted
          .map do |(hex, color_alpha), weight|
            ColorMath::Converters.hex_to_rgb(hex).map { |channel| channel * color_alpha * weight }
          end
          .transpose
          .map { |channels| (channels.sum / alpha).round.clamp(0, 255) }
      [ColorMath::Converters.rgb_to_hex(rgb), alpha.clamp(0.0, 1.0)]
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
    # Site-wide text colors that BACKGROUND_TEXT backgrounds rely on.
    SITE_WIDE_TEXT = %w[--primary --d-sys-color-text-default].freeze

    # Backgrounds an area rule can paint instead, with that area.
    BACKGROUND_AREAS = { "--d-category-box-background-color" => "category_box" }.freeze

    BACKGROUND_TEXT = {
      "--d-comp-DBadgeCard-color-background" => "--primary",
      "--d-category-box-background-color" => "--primary",
      "--d-content-background" => "--primary",
      "--d-post-aside-background" => "--primary",
      "--d-sidebar-background" => "--d-sidebar-link-color",
      "--d-sidebar-highlight-hover-background" => "--d-sidebar-highlight-color",
      "--d-unread-notification-background" => "--primary",
      "--d-sys-color-background-default" => "--d-sys-color-text-default",
      "--d-sys-color-background-default-hovered" => "--d-sys-color-text-default",
      "--d-sys-color-background-default-pressed" => "--d-sys-color-text-default",
      "--d-sys-color-background-default-focused" => "--d-sys-color-text-default",
      "--d-sys-color-background-default-selected" => "--d-sys-color-text-default",
    }.freeze

    # Background and text variables that render together, found by naming
    # convention (-bg-color, -background-color or -background with
    # -text-color or -color, and a component's -color-background with its
    # -color-text and -color-icon), plus the backgrounds whose text is listed
    # above.
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
              if (match = variable.name.match(/\A(--d-comp-.*-color)-background(-.+)?\z/))
                base, rest = match.captures
                named = "#{base}-text#{rest}"
                icon = "#{base}-icon#{rest}"
                texts = [(@registry[named] ? named : texts.first), (icon if @registry[icon])]
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
            variable.name.match?(/\A--token-color-(text|icon)-/) ||
            variable.name.match?(/-color-(text|icon)(-|\z)/)
        ) && !variable.name.match?(/background|-bg-|bg-color|border|shadow|outline|divider|fill/)
    end

    # The background a text or icon variable without a pair shows on.
    def foreground_background(name)
      case name
      when /\A--d-sidebar-/
        "--d-sidebar-background"
      when /\A--d-header-/, /\A--d-comp-Header-/
        "--header_background"
      when /\A--token-color-/, /\A--d-sys-color-/
        "--d-sys-color-background-default"
      else
        "--secondary"
      end
    end

    # The color a background variable shows: a see-through one is composited
    # onto what core shows around it.
    def shown_variable_background(name, mode, use_draft: true)
      hex = resolve_variable(name, mode, use_draft:)
      return hex if hex != :translucent

      around = foreground_background(name)
      around = "--secondary" if around == name
      shown_background(
        CssValue.parse("var(#{name})").first,
        nil,
        mode,
        behind: "var(#{around})",
        use_draft:,
      )
    end

    # Text needs 4.5:1 and icons 3:1 (WCAG non-text contrast). Core's own
    # defaults miss 4.5:1 in places, so a pair passes when it is AA or at
    # least as readable as core's default.
    def readable_variables?(variables, path = "variables")
      variable_pairs
        .map do |background, text|
          next true if !variables.key?(background) && !variables.key?(text)

          %w[light dark]
            .map do |mode|
              background_hex = shown_variable_background(background, mode)
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
              default_background = shown_variable_background(background, mode, use_draft: false)
              default_text = resolve_variable(text, mode, use_draft: false)
              if default_background.is_a?(String) && default_text.is_a?(String)
                required = [required, contrast(default_text, default_background)].min
              end
              next true if ratio >= required
              error(
                path,
                "#{text} on #{background} is #{ratio}:1 in #{mode} mode; it needs #{required}:1 (#{text} is ##{text_hex}, #{background} is ##{background_hex}).#{variable_pair_hint(background, text)}",
              )
            end
            .all?
        end
        .all?
    end

    # The text color of a background in BACKGROUND_TEXT is used across the
    # site, so it can't be changed for the background alone. Where an area
    # rule can paint the same background, the override is better replaced by
    # a rule that sets both colors.
    def variable_pair_hint(background, text)
      return "" if BACKGROUND_TEXT[background] != text || !SITE_WIDE_TEXT.include?(text)

      if (area = BACKGROUND_AREAS[background])
        " #{text} is used across the site, so instead of overriding #{background}, remove it and set both background-color and a readable color in a rule for the #{area} area."
      else
        " #{text} is used across the site and can't change for #{background} alone, so give #{background} a color #{text} stays readable on."
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
      return if colors.any? { |_, percent| percent && !percent.between?(0, 100) }

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
          percents = parts.drop(1).flatten.select { |n| n.type == :dimension && n.unit == "%" }
          if percents.any? { |n| !n.value.between?(0, 100) }
            return error(path, "color-mix() percentages must be between 0% and 100%")
          end
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
            "raw color #{node.value}() must use a palette variable, as var(--primary) or color-mix(in srgb, var(--primary) 10%, transparent), or be hex inside light-dark()",
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
