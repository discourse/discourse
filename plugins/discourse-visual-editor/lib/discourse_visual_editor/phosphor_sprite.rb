# frozen_string_literal: true

module DiscourseVisualEditor
  # Builds the Phosphor SVG sprite at `svg-icons/phosphor.svg` from the
  # manifest at `svg-icons/phosphor-icons.txt`. Each manifest entry maps
  # to a single `<symbol id="ve-<name>">` element in the sprite.
  #
  # The manifest is the source of truth. The sprite is committed so that
  # production never needs the `@phosphor-icons/core` source files.
  module PhosphorSprite
    PLUGIN_ROOT = File.expand_path("../..", __dir__)
    MANIFEST_PATH = File.join(PLUGIN_ROOT, "svg-icons", "phosphor-icons.txt")
    SPRITE_PATH = File.join(PLUGIN_ROOT, "svg-icons", "phosphor.svg")
    SOURCE_DIR = File.join(PLUGIN_ROOT, "node_modules", "@phosphor-icons", "core", "assets", "fill")
    ICON_PREFIX = "ve-"

    class MissingSourceError < StandardError
    end

    class MissingIconError < StandardError
    end

    def self.manifest_names
      return [] unless File.exist?(MANIFEST_PATH)

      File
        .foreach(MANIFEST_PATH, chomp: true)
        .filter_map do |line|
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?("#")
          stripped
        end
        .sort
        .uniq
    end

    # True when the manifest has been modified since the sprite was last
    # written (or when the sprite doesn't exist yet).
    def self.stale?
      return false unless File.exist?(MANIFEST_PATH)
      return true unless File.exist?(SPRITE_PATH)
      File.mtime(MANIFEST_PATH) > File.mtime(SPRITE_PATH)
    end

    def self.generate!
      unless File.directory?(SOURCE_DIR)
        raise MissingSourceError,
              "Phosphor source SVGs not found at #{SOURCE_DIR}. " \
                "Run `pnpm install` from the repo root."
      end

      names = manifest_names
      symbols = names.map { |name| symbol_for(name) }

      sprite = +"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
      sprite << "<svg xmlns=\"http://www.w3.org/2000/svg\" style=\"display: none;\">\n"
      symbols.each { |s| sprite << "  #{s}\n" }
      sprite << "</svg>\n"

      File.write(SPRITE_PATH, sprite)
      names
    end

    def self.symbol_for(name)
      source_path = File.join(SOURCE_DIR, "#{name}-fill.svg")
      unless File.exist?(source_path)
        raise MissingIconError,
              "Phosphor icon \"#{name}\" not found at #{source_path}. " \
                "Check the name at https://phosphoricons.com/ (Fill variant)."
      end

      # Phosphor Fill source files use viewBox="0 0 256 256" and rely on
      # `fill="currentColor"` set on the wrapping <svg>. Rewriting the
      # root element as a <symbol> with the same attributes preserves
      # rendering; dropping width/height lets the consumer size the icon
      # via CSS.
      File
        .read(source_path)
        .sub(/\A<\?xml[^>]*\?>\s*/, "")
        .sub(
          /<svg\b[^>]*>/,
          %(<symbol id="#{ICON_PREFIX}#{name}" viewBox="0 0 256 256" fill="currentColor">),
        )
        .sub(%r{</svg>\s*\z}, "</symbol>")
        .strip
    end
  end
end
