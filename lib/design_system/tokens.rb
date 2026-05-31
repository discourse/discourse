# frozen_string_literal: true

# Single source of truth for the design-system tokens.
#
# Reads the DTCG token JSON committed at
# app/assets/stylesheets/common/design-system/{base,system}.json and produces both
# runtime artifacts — there is no committed SCSS and no Node build step:
#
#   .css                -> the `:root{ --d-system-* }` block injected into the
#                          `common` stylesheet at compile time (see
#                          Stylesheet::Importer#import_design_system_tokens). Base
#                          palette values are inlined into the semantic tokens, so
#                          `--d-base-*` is never exposed — base is an authoring
#                          concept, not a runtime variable.
#
#   .color_scheme(mode) -> the legacy ColorScheme anchors (primary, secondary, …)
#                          derived from the semantic colour tokens, for
#                          ColorScheme::BUILT_IN_SCHEMES.
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

    class << self
      # The `:root{ --d-system-* }` block. Only the semantic layer is emitted;
      # references to the base palette are resolved and inlined.
      def css
        declarations =
          flatten(system).map { |token| "  --#{token[:path].join("-")}: #{css_value(token)};" }
        ":root {\n#{declarations.join("\n")}\n}\n"
      end

      # Legacy ColorScheme anchors for a built-in scheme. `mode` is :light or :dark.
      def color_scheme(mode)
        ANCHOR_ORDER.index_with do |anchor|
          if (path = ANCHOR_TOKENS[anchor])
            terminal(system.dig("d-system", "color", *path))[mode == :dark ? :dark : :light]
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

      # The CSS value for a semantic token: follow any base reference and emit the
      # resolved literal (light-dark() for colours, the bare value otherwise).
      def css_value(token)
        resolved = terminal_node(token[:node])
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
      def terminal(node)
        resolved = terminal_node(node)
        light = resolved["$value"].delete_prefix("#")
        dark =
          (resolved.dig("$extensions", DARK_EXTENSION) || resolved["$value"]).delete_prefix("#")
        { light: light, dark: dark }
      end

      # Follow `{group.name…}` references (across base or system) until a concrete
      # token node is reached.
      def terminal_node(node)
        value = node["$value"]
        return node unless value.is_a?(String) && (ref = value[/\A\{(.+)\}\z/, 1])

        path = ref.split(".")
        root = path.first == "d-base" ? base : system
        target = root.dig(*path)
        raise "design-system token reference not found: #{value}" if target.nil?

        terminal_node(target)
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
