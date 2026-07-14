# frozen_string_literal: true

module DiscourseWireframe
  # Builds the Lucide SVG sprite at `svg-icons/lucide.svg` from the
  # manifest at `svg-icons/lucide-icons.txt`. Each manifest entry maps
  # to a single `<symbol id="wf-<name>">` element in the sprite.
  #
  # The manifest is the source of truth. The sprite is committed so that
  # production never needs the `lucide-static` source files.
  module LucideSprite
    PLUGIN_ROOT = File.expand_path("../..", __dir__)
    MANIFEST_PATH = File.join(PLUGIN_ROOT, "svg-icons", "lucide-icons.txt")
    SPRITE_PATH = File.join(PLUGIN_ROOT, "svg-icons", "lucide.svg")
    SOURCE_DIR = File.join(PLUGIN_ROOT, "node_modules", "lucide-static", "icons")
    ICON_PREFIX = "wf-"

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
              "Lucide source SVGs not found at #{SOURCE_DIR}. " \
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
      source_path = File.join(SOURCE_DIR, "#{name}.svg")
      unless File.exist?(source_path)
        raise MissingIconError,
              "Lucide icon \"#{name}\" not found at #{source_path}. " \
                "Check the name at https://lucide.dev/icons/."
      end

      # Lucide source files use viewBox="0 0 24 24" with stroke-based
      # rendering (fill="none", stroke="currentColor", stroke-width="2",
      # round caps/joins). Hoisting those stroke attributes onto the
      # <symbol> ensures the icon renders identically when referenced
      # via <use>; dropping width/height lets the consumer size it via
      # CSS, and stripping the leading license comment keeps the sprite
      # tidy.
      File
        .read(source_path)
        .sub(/\A<!--[^>]*-->\s*/, "")
        .sub(/\A<\?xml[^>]*\?>\s*/, "")
        .sub(
          /<svg\b[^>]*>/m,
          %(<symbol id="#{ICON_PREFIX}#{name}" viewBox="0 0 24 24" fill="none" ) +
            %(stroke="currentColor" stroke-width="2" stroke-linecap="round" ) +
            %(stroke-linejoin="round">),
        )
        .sub(%r{</svg>\s*\z}, "</symbol>")
        .gsub(/\s+/, " ")
        .strip
    end
  end
end
