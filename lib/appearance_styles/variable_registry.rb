# frozen_string_literal: true

# The core design variables generated theme styles may override, with their
# type, where core defines them, and bounds for anything size-like.
#
# The variables themselves come from AppearanceStyles::VariableInventory, which
# reads them from compiled core CSS; the rules below decide which ones styles
# may change.
module AppearanceStyles
  class VariableRegistry
    Variable =
      Data.define(
        :name,
        :type,
        :scope,
        :selectors,
        :default,
        :allowed,
        :reason,
        :min_px,
        :max_px,
        :keywords,
      ) do
        def root?
          scope == "root"
        end
      end

    # Internal or structural families that styles should not touch.
    EXCLUDED_PREFIXES = %w[
      --d-access-control-
      --d-date-range-picker-
      --d-drag-
      --d-overflow-controls-
      --d-post-accordion-
      --d-skeleton-
      --d-tooltip-
      --d-sidebar-animation-
      --d-table-
      --d-font-family
      --d-topic-list-likes-views-posts-width
    ].freeze

    # Corrections where the type read from a default value is wrong.
    TYPE_FIXES = {
      /font-size\z/ => "length",
      /-transition\z/ => "excluded",
      /-border(--[a-z]+)?\z/ => "border",
      # a fade gradient that needs relative color syntax
      /\A--d-sidebar-footer-fade\z/ => "excluded",
    }.freeze

    UNAUTHORABLE_TYPES = %w[excluded font_family easing time alias_unresolved].freeze

    # [pattern, min px, max px]; the first match wins. em and rem count as 16px.
    LENGTH_BOUNDS = [
      [/radius-(full|pill)\z/, 0, 9999],
      # pill-shaped buttons and inputs
      [/(button|input)-border-radius\z/, 0, 9999],
      [/-(DButton|Input)-border-radius\z/, 0, 9999],
      [/radius/, 0, 32],
      [/font-size|header-size/, 11, 48],
      [/max-width\z/, 960, 1600],
      [/sidebar-width\z/, 192, 384],
      [/avatar-size\z/, 16, 64],
      [/logo-height\z/, 24, 112],
      [/(icon|emoji)-size\z/, 12, 32],
      [/row-height\z/, 24, 56],
      [/welcome-banner-height\z/, 96, 480],
      [/(border|accent|box)-width\z|underline-height\z/, 0, 8],
      [/padding|margin|gap|space|prefix-width/, 0, 64],
    ].freeze

    KEYWORDS = {
      /text-decoration\z/ => %w[none underline],
      /text-alignment\z/ => %w[left center right start end],
    }.freeze

    # Built again when core's stylesheets change.
    def self.instance
      cachebuster = Stylesheet::Manager.fs_asset_cachebuster
      if @instance.nil? || @cachebuster != cachebuster
        @instance = new(VariableInventory.current)
        @cachebuster = cachebuster
      end
      @instance
    end

    def initialize(inventory)
      @palette_names = inventory["palette_variables"].to_set.freeze
      @variables = inventory["variables"].to_h { |entry| [entry["name"], build(entry)] }.freeze
    end

    def [](name)
      @variables[name]
    end

    def all
      @variables.values
    end

    def allowed
      all.select(&:allowed)
    end

    def palette_variable?(name)
      @palette_names.include?(name)
    end

    def palette_variables
      @palette_names.sort
    end

    # Variables a value may reference through var(): palette colors, core
    # design variables, and core's spacing and font scales.
    def referenceable?(name)
      palette_variable?(name) || @variables.key?(name) ||
        name.match?(/\A--(space|font)-[\w-]+\z/) ||
        name.match?(/\A--(font-family|heading-font-family)\z/)
    end

    private

    def build(entry)
      name = entry["name"]
      type = entry["type"]
      TYPE_FIXES.each { |pattern, fixed| type = fixed if name.match?(pattern) }

      allowed = true
      reason = nil
      min_px = max_px = nil
      keywords = nil

      if EXCLUDED_PREFIXES.any? { |prefix| name.start_with?(prefix) }
        allowed = false
        reason = "internal or structural"
      elsif UNAUTHORABLE_TYPES.include?(type)
        allowed = false
        reason = "type #{type} is not authorable"
      elsif type == "length"
        _, min_px, max_px = LENGTH_BOUNDS.find { |pattern, _, _| name.match?(pattern) }
        if min_px.nil?
          allowed = false
          reason = "no bounds defined"
        end
      elsif type == "keyword"
        keywords = KEYWORDS.find { |pattern, _| name.match?(pattern) }&.last
        if keywords.nil?
          allowed = false
          reason = "no keyword list defined"
        end
      end

      Variable.new(
        name:,
        type:,
        scope: entry["scope"],
        selectors: entry["selectors"],
        default: entry["default"],
        allowed:,
        reason:,
        min_px:,
        max_px:,
        keywords:,
      )
    end
  end
end
