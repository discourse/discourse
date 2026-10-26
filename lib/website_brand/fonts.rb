# frozen_string_literal: true

module WebsiteBrand
  # Matches a CSS font stack to one of the fonts Discourse offers. Only the
  # Discourse font's key is kept, never the name found on the page.
  module Fonts
    Match = Data.define(:key, :exact)

    SYSTEM_FAMILIES = %w[
      systemui
      applesystem
      blinkmacsystemfont
      segoeui
      uisansserif
      sansserif
    ].freeze
    # What a family name can add to a font's name and still be that font, as in
    # "Inter Variable" or the "__Inter_d65c78" names that font loaders make.
    VARIANT_SUFFIXES = /\A(?:var|variable|vf|display|text|web|neue|fallback|(?=[a-f]*\d)\h{5,})*\z/
    SERIF_FALLBACK = "merriweather"
    MONOSPACE_FALLBACK = "jet_brains_mono"

    # Returns nil when the stack is blank or names no font.
    def self.match(stack)
      families =
        CssValue
          .split_arguments(stack.to_s)
          .map { |family| family.delete("\"'").strip }
          .compact_blank
      return if families.empty?

      if (key = discourse_font_key(families.first))
        return Match.new(key:, exact: true)
      end

      key = fallback_key(families)
      Match.new(key:, exact: false) if key
    end

    def self.discourse_font_key(family)
      name = normalize(family)
      return "system" if SYSTEM_FAMILIES.include?(name)

      font =
        DiscourseFonts.fonts.find do |candidate|
          [candidate[:name], candidate[:key]].any? do |font_name|
            font_name = normalize(font_name)
            name.start_with?(font_name) && name.delete_prefix(font_name).match?(VARIANT_SUFFIXES)
          end
        end
      font&.dig(:key)
    end
    private_class_method :discourse_font_key

    # The font Discourse would pick for the stack's generic family.
    def self.fallback_key(families)
      generic =
        families.map(&:downcase).reverse.find { |family| %w[serif monospace].include?(family) }
      key =
        case generic
        when "serif"
          SERIF_FALLBACK
        when "monospace"
          MONOSPACE_FALLBACK
        else
          SiteSetting.defaults[:base_font]
        end
      key if DiscourseFonts.fonts.any? { |font| font[:key] == key }
    end
    private_class_method :fallback_key

    def self.normalize(name)
      name.to_s.downcase.gsub(/[^a-z0-9]/, "")
    end
    private_class_method :normalize
  end
end
