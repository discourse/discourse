# frozen_string_literal: true

# Single source of truth for the design-system tokens.
#
# Reads the DTCG token JSON committed at
# app/assets/stylesheets/common/design-system/{base,system}.json and produces the
# runtime artifacts — there is no committed SCSS and no Node build step:
#
#   .css                       -> the `:root{ --d-system-* }` block for the core
#                                 defaults, injected into the `common` stylesheet
#                                 (Stylesheet::Importer#import_design_system_tokens).
#                                 Base palette values are inlined, so `--d-base-*`
#                                 is never exposed — base is an authoring concept.
#
#   .theme_css(overrides)      -> the `:root{}` block for a theme's *overridden*
#                                 system tokens only, injected into that theme's
#                                 stylesheet so it wins over core via the cascade.
#
#   .color_scheme(mode, ovr)   -> the legacy ColorScheme anchors derived from the
#                                 semantic tokens (core, or merged with a theme's
#                                 overrides), for ColorScheme::BUILT_IN_SCHEMES and
#                                 per-theme schemes.
#
# Themes override the semantic layer only: a theme ships a partial `system.json`,
# merged over the core system layer; the base palette is always core.
module DesignSystem
  module Tokens
    DARK_EXTENSION = "com.discourse.dark"

    GENERIC_FONT_FAMILIES = %w[
      serif
      sans-serif
      monospace
      cursive
      fantasy
      system-ui
      ui-serif
      ui-sans-serif
      ui-monospace
      ui-rounded
      math
      emoji
      fangsong
    ].freeze

    # Legacy ColorScheme anchor => the semantic colour token (under d-system.color)
    # it derives from. Light value is the token's resolved base colour; dark value
    # is that base colour's `com.discourse.dark` extension.
    ANCHOR_TOKENS = {
      "primary" => %w[text default],
      "secondary" => %w[surface default],
      "tertiary" => %w[interactive default],
      "header_background" => %w[surface default],
      "header_primary" => %w[text default],
      "highlight" => %w[surface highlight],
      "selected" => %w[surface selected],
      "hover" => %w[surface hovered],
      "danger" => %w[text danger],
      "success" => %w[text success],
      "love" => %w[text love],
    }.freeze

    # Anchors with no semantic token source. quaternary is unused by the design
    # system but ColorScheme expects every anchor present.
    ANCHOR_DEFAULTS = { "quaternary" => { light: "1868db", dark: "7ab0fb" } }.freeze

    # Kept stable so the generated schemes diff cleanly.
    ANCHOR_ORDER = %w[
      primary
      secondary
      tertiary
      quaternary
      header_background
      header_primary
      highlight
      selected
      hover
      danger
      success
      love
    ].freeze

    # OFF mode (enable_design_system false): each --d-system-* points at the
    # equivalent legacy theme variable, so blocks built on the tokens inherit the
    # site's current ColorScheme/fonts. Keyed by the flattened token path (which
    # includes the "d-system" prefix). Colour + body/heading-font tokens are
    # mapped; everything without an entry (radius/space/size, font size/weight/
    # line-height, the code font) keeps its literal design-system value.
    LEGACY_MAP = {
      %w[d-system color surface default] => "var(--secondary)",
      %w[d-system color surface sunken] => "var(--primary-low)",
      %w[d-system color surface raised] => "var(--secondary)",
      %w[d-system color surface hovered] => "var(--d-hover)",
      %w[d-system color surface selected] => "var(--d-selected)",
      %w[d-system color surface brand] => "var(--tertiary)",
      %w[d-system color surface brand-hovered] => "var(--tertiary-hover)",
      %w[d-system color surface danger] => "var(--danger-low)",
      %w[d-system color surface success] => "var(--success-low)",
      %w[d-system color surface highlight] => "var(--highlight)",
      %w[d-system color text default] => "var(--primary)",
      %w[d-system color text subtle] => "var(--primary-medium)",
      %w[d-system color text inverse] => "var(--secondary)",
      %w[d-system color text brand] => "var(--tertiary)",
      %w[d-system color text danger] => "var(--danger)",
      %w[d-system color text success] => "var(--success)",
      %w[d-system color text link] => "var(--tertiary)",
      %w[d-system color text link-hover] => "var(--tertiary-hover)",
      %w[d-system color text highlight] => "var(--primary)",
      %w[d-system color text love] => "var(--love)",
      %w[d-system color border default] => "var(--primary-low-mid)",
      %w[d-system color border bold] => "var(--primary-medium)",
      %w[d-system color border subtle] => "var(--primary-low)",
      %w[d-system color border brand] => "var(--tertiary)",
      %w[d-system color border danger] => "var(--danger)",
      %w[d-system color interactive default] => "var(--tertiary)",
      %w[d-system color interactive hovered] => "var(--tertiary-hover)",
      %w[d-system color interactive pressed] => "var(--tertiary-hover)",
      %w[d-system font family body] => "var(--font-family)",
      %w[d-system font family heading] => "var(--heading-font-family)",
    }.freeze

    class << self
      # The `:root{ --d-system-* }` block, always injected into the `common`
      # stylesheet. ON (enable_design_system): tokens resolve to our d-base palette
      # values (and the legacy ColorScheme is synced from them). OFF: they resolve
      # to the site's legacy theme variables (LEGACY_MAP), so blocks built on
      # --d-system-* inherit whatever theme the site already runs.
      def css
        return legacy_css unless SiteSetting.enable_design_system

        emit_block(flatten(system), system)
      end

      # The `:root{}` block for a theme's overridden system tokens only. `overrides`
      # is a parsed partial system.json (rooted at "d-system"); returns "" if empty.
      def theme_css(overrides)
        return "" unless SiteSetting.enable_design_system
        return "" if overrides.blank?

        tokens = flatten(overrides)
        return "" if tokens.empty?

        emit_block(tokens, system.deep_merge(overrides))
      end

      # Legacy ColorScheme anchors. `mode` is :light or :dark; `overrides` is an
      # optional theme partial system.json merged over the core system layer.
      def color_scheme(mode, overrides = {})
        sys = overrides.present? ? system.deep_merge(overrides) : system
        ANCHOR_ORDER.index_with do |anchor|
          if (path = ANCHOR_TOKENS[anchor])
            terminal(sys.dig("d-system", "color", *path), sys)[mode == :dark ? :dark : :light]
          else
            ANCHOR_DEFAULTS.dig(anchor, mode)
          end
        end
      end

      private

      def dir
        @dir ||= Rails.root.join("app/assets/stylesheets/common/design-system")
      end

      # Parsed JSON is intentionally not memoized: it is only read at stylesheet
      # compile / boot, both of which are cached downstream, and re-reading keeps
      # token edits live in development.
      def base
        JSON.parse(File.read(dir.join("base.json")))
      end

      def system
        JSON.parse(File.read(dir.join("system.json")))
      end

      # Flatten a DTCG tree to leaf tokens, carrying the full path (so the top-level
      # "d-system" key becomes the `--d-system-` prefix).
      def flatten(node, path = [], out = [])
        node.each do |key, value|
          next if key.start_with?("$")
          next unless value.is_a?(Hash)

          if value.key?("$value")
            out << { path: path + [key], node: value }
          else
            flatten(value, path + [key], out)
          end
        end
        out
      end

      def emit_block(tokens, sys)
        declarations = tokens.map { |t| "  --#{t[:path].join("-")}: #{css_value(t[:node], sys)};" }
        ":root {\n#{declarations.join("\n")}\n}\n"
      end

      # OFF-mode block: each --d-system-* points at its legacy theme variable
      # (LEGACY_MAP); tokens with no mapping keep their literal value.
      def legacy_css
        declarations =
          flatten(system).map do |t|
            value = LEGACY_MAP[t[:path]] || css_value(t[:node], system)
            "  --#{t[:path].join("-")}: #{value};"
          end
        ":root {\n#{declarations.join("\n")}\n}\n"
      end

      # The CSS value for a semantic token: follow any reference (resolved against
      # `sys` for d-system aliases, core base for d-base) and emit the literal.
      def css_value(node, sys)
        resolved = terminal_node(node, sys)
        value = resolved["$value"]
        dark = resolved.dig("$extensions", DARK_EXTENSION)

        case resolved["$type"]
        when "color"
          light_dark(shorten_hex(value), dark && shorten_hex(dark))
        when "fontFamily"
          quote_font_families(value)
        else
          light_dark(value, dark)
        end
      end

      # Resolve a token to {light:, dark:} hex (no leading #), for scheme anchors.
      def terminal(node, sys)
        resolved = terminal_node(node, sys)
        light = resolved["$value"].delete_prefix("#")
        dark =
          (resolved.dig("$extensions", DARK_EXTENSION) || resolved["$value"]).delete_prefix("#")
        { light: light, dark: dark }
      end

      # Follow `{group.name…}` references until a concrete token node is reached.
      # d-base aliases resolve against the core base palette; d-system aliases
      # against `sys` (core, or core merged with a theme's overrides).
      def terminal_node(node, sys)
        value = node["$value"]
        return node unless value.is_a?(String) && (ref = value[/\A\{(.+)\}\z/, 1])

        path = ref.split(".")
        root = path.first == "d-base" ? base : sys
        target = root.dig(*path)
        raise "design-system token reference not found: #{value}" if target.nil?

        terminal_node(target, sys)
      end

      def light_dark(light, dark)
        dark.nil? ? light.to_s : "light-dark(#{light}, #{dark})"
      end

      def shorten_hex(value)
        m = value.match(/\A#(\h)\1(\h)\2(\h)\3\z/)
        m ? "##{m[1]}#{m[2]}#{m[3]}" : value
      end

      def quote_font_families(value)
        value
          .split(",")
          .map(&:strip)
          .map do |family|
            GENERIC_FONT_FAMILIES.include?(family.downcase) ? family : "\"#{family}\""
          end
          .join(", ")
      end
    end
  end
end
