# frozen_string_literal: true

# Every design variable core defines, read from the CSS core actually ships
# (not the SCSS sources): its type, whether it is defined on the root element,
# its default and the selectors that define it. AppearanceStyles::VariableRegistry
# applies the rules for which ones styles may change on top of this.
#
# Compiling core's CSS takes a few seconds, so the result is kept in a file
# per version of core's stylesheets, shared by every process and site, and
# built again when the stylesheets change.
module AppearanceStyles
  class VariableInventory
    CACHE_DIR = "tmp/appearance_styles"
    DESIGN_PREFIXES = %w[--d- --token- --hljs-].freeze
    ROOT_SELECTORS = %w[:root html :root,html html,:root].freeze
    MAX_SELECTORS = 6
    # No theme or palette has this ID, so compiling falls back to core's own.
    NO_THEME = 0

    PALETTE_PREFIXES = %w[
      --primary
      --secondary
      --tertiary
      --quaternary
      --header_background
      --header_primary
      --highlight
      --danger
      --success
      --love
      --d-sys-color-background-default-selected
      --d-sys-color-background-default-hovered
      --d-sys-color-text-default-selected
      --d-sys-color-background-highlight-subtle
      --d-sys-color-background-danger-subtle
      --d-sys-color-background-danger-hovered
      --d-sys-color-background-success-subtle
      --d-sys-color-background-success-hovered
      --d-sys-color-background-love-subtlest
    ].freeze

    # { "variables" => [{ "name", "type", "scope", "default", "selectors" }],
    #   "palette_variables" => ["--primary", ...] }
    def self.current
      path = cache_path
      cached = read(path)
      return cached if cached

      inventory = new.build
      FileUtils.mkdir_p(File.dirname(path))
      temporary = "#{path}.#{SecureRandom.hex(4)}.tmp"
      File.write(temporary, JSON.generate(inventory))
      File.rename(temporary, path)
      inventory
    end

    def self.cache_path
      directory = Rails.root.join(CACHE_DIR)
      directory = directory.join("test_#{Discourse.test_env_number}") if Rails.env.test?
      digest = Digest::SHA1.hexdigest(Stylesheet::Manager.fs_asset_cachebuster)
      directory.join("variables-#{digest}.json").to_s
    end

    def self.read(path)
      JSON.parse(File.read(path)) if File.exist?(path)
    rescue JSON::ParserError
      nil
    end
    private_class_method :read

    def build
      definitions = compiled_css.flat_map { |css| definitions(css) }
      names = definitions.map { |definition| definition[:name] }.uniq.sort

      variables =
        names
          .select { |name| name.start_with?(*DESIGN_PREFIXES) }
          .map { |name| variable(name, definitions.select { |d| d[:name] == name }) }
      resolve_aliases(variables)

      {
        "variables" => variables,
        "palette_variables" => names.select { |name| name.start_with?(*PALETTE_PREFIXES) },
      }
    end

    private

    # Compiled without a theme and with core's base palette, so a site's
    # theme can't add variables or change defaults, and every site gets the
    # same list.
    def compiled_css
      %i[common color_definitions].map do |target|
        Stylesheet::Compiler.compile_asset(
          target,
          theme_id: NO_THEME,
          color_scheme_id: NO_THEME,
        ).first
      end
    end

    def definitions(css)
      found = []
      walk(Crass.parse(css), nil) do |selector, properties, media|
        properties.each do |property|
          next if !property[:name].start_with?("--")
          found << { name: property[:name], value: property[:value], selector:, media: }
        end
      end
      found
    end

    def walk(nodes, media, &block)
      nodes.each do |node|
        case node[:node]
        when :style_rule
          properties = node[:children].select { |child| child[:node] == :property }
          yield node[:selector][:value], properties, media
        when :at_rule
          next if node[:block].blank?
          prelude = Crass::Parser.stringify(node[:prelude]).strip
          walk(
            Crass::Parser.parse_rules(node[:block]),
            [media, "@#{node[:name]} #{prelude}"].compact.join(" "),
            &block
          )
        end
      end
    end

    # Compiled CSS replaces light-dark() with a fallback for older browsers,
    # and keeps the original under @supports.
    def native_light_dark(definitions)
      definitions.find do |definition|
        definition[:media]&.start_with?("@supports") &&
          definition[:value].include?("light-dark(") &&
          ROOT_SELECTORS.include?(definition[:selector].delete(" "))
      end
    end

    def root?(definition)
      ROOT_SELECTORS.include?(definition[:selector].delete(" ")) && definition[:media].nil?
    end

    def variable(name, definitions)
      root_definition =
        native_light_dark(definitions) || definitions.find { |definition| root?(definition) } ||
          definitions.first
      {
        "name" => name,
        "type" => infer_type(name, root_definition[:value]),
        "scope" => definitions.any? { |definition| root?(definition) } ? "root" : "scoped",
        "default" => root_definition[:value],
        "selectors" =>
          definitions
            .map { |definition| [definition[:selector], definition[:media]].compact.join(" ") }
            .uniq
            .first(MAX_SELECTORS),
      }
    end

    def infer_type(name, value)
      nodes =
        begin
          CssValue.parse(value)
        rescue CssValue::ParseError
          return "unparseable"
        end
      flat = []
      CssValue.each_node(nodes) { |node| flat << node }
      functions = flat.select { |node| node.type == :function }.map(&:value)
      idents = flat.select { |node| node.type == :ident }.map(&:value)
      dimensions = flat.select { |node| node.type == :dimension }
      top = nodes.reject { |node| node.type == :comma }

      palette_reference =
        flat.any? do |node|
          node.type == :function && node.value == "var" && node.children.first&.type == :ident &&
            node.children.first.value.start_with?(*PALETTE_PREFIXES)
        end
      color_function = (functions & %w[rgb rgba hsl hsla light-dark color-mix oklch oklab]).any?

      return "shadow" if name.include?("shadow")
      if name.end_with?("-border", *%w[top right bottom left].map { "border-#{it}" })
        return "border"
      end
      return "time" if dimensions.any? { |node| %w[s ms].include?(node.unit) } && top.size == 1
      if functions.include?("cubic-bezier") ||
           (idents & %w[ease ease-in ease-out ease-in-out linear]).any?
        return "easing"
      end
      return "font_weight" if name.include?("weight")
      return "font_family" if name.include?("font-family")
      if palette_reference || color_function || flat.any? { |node| node.type == :hash } ||
           name.match?(/color|background|-bg\b|bg-/)
        return "color"
      end
      if top.size == 1 &&
           (
             top.first.type == :dimension ||
               (top.first.type == :function && %w[calc min max clamp].include?(top.first.value)) ||
               (top.first.type == :number && top.first.value.zero?)
           )
        return "length"
      end
      return "number" if top.size == 1 && top.first.type == :number
      return "keyword" if top.size == 1 && top.first.type == :ident
      return "alias" if top.size == 1 && top.first.type == :function && top.first.value == "var"
      "compound"
    end

    # `--d-x: var(--d-y)` takes the type of what it points at.
    def resolve_aliases(variables)
      by_name = variables.index_by { |variable| variable["name"] }
      variables.each do |variable|
        next if variable["type"] != "alias"

        seen = Set.new
        current = variable
        while current && current["type"] == "alias" && seen.add?(current["name"])
          target = current["default"][/\Avar\((--[\w-]+)/, 1]
          if target&.start_with?(*PALETTE_PREFIXES)
            current = { "type" => "color" }
            break
          end
          current = by_name[target]
        end

        alias_of = variable["default"][/\Avar\((--[\w-]+)/, 1].to_s
        variable["type"] = if current
          current["type"]
        elsif alias_of.start_with?("--space-", "--font-")
          "length"
        else
          "alias_unresolved"
        end
      end
    end
  end
end
