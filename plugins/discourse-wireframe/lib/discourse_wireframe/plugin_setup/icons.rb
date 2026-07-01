# frozen_string_literal: true

require_relative "../lucide_sprite"

module DiscourseWireframe
  module PluginSetup
    # Registers every SVG icon the blocks system and editor UI need that isn't in
    # the default SVG subset, plus the generated Lucide sprite's icons.
    #
    # There are TWO independent registries here; adding to or removing from one
    # never affects the other:
    #
    #   1. `EXTRA` below — plain (unprefixed) FontAwesome ids, e.g. `heading`.
    #   2. The Lucide set — driven solely by `svg-icons/lucide-icons.txt` and
    #      registered with a `wf-` prefix, e.g. `wf-align-center`. It does NOT
    #      read `EXTRA`.
    #
    # A name may appear in both (e.g. `align-center` as a FontAwesome glyph and
    # `wf-align-center` as a Lucide glyph) — they are different icons under
    # different ids. Use the `wf-` form to reach a Lucide glyph; removing the
    # plain name from `EXTRA` leaves the `wf-` one untouched, and vice versa.
    module Icons
      # Plain (unprefixed) FontAwesome ids used by block-metadata `icon:` fields
      # and inspector UI that aren't in the default SVG subset. Without these the
      # rendered icon is replaced by a placeholder square and the console logs a
      # warning per missing glyph. (Lucide `wf-` icons are handled separately via
      # the manifest — see the module comment above.)
      EXTRA = %w[
        arrows-left-right
        arrows-up-down
        border-none
        bullhorn
        circle-dashed
        circle-half-stroke
        circle-user
        cube
        cubes
        desktop
        down-left-and-up-right-to-center
        down-long
        fire
        folder-tree
        grip-lines
        heading
        mobile-screen-button
        object-group
        paragraph
        photo-film
        shield-halved
        table-cells-large
        table-columns
        tablet-screen-button
        triangle-exclamation
        up-long
        up-right-and-down-left-from-center
        user
        user-xmark
        wand-magic-sparkles
      ].freeze

      def self.apply(plugin)
        # Registry 1: plain FontAwesome ids.
        EXTRA.each { |icon| plugin.register_svg_icon(icon) }

        regenerate_lucide_sprite_if_stale

        # Registry 2: the Lucide set. Each manifest entry is registered with a
        # `wf-` prefix so it can be referenced as `wf-<name>` from templates.
        # This is independent of `EXTRA` — it reads only the manifest.
        LucideSprite.manifest_names.each do |name|
          plugin.register_svg_icon("#{LucideSprite::ICON_PREFIX}#{name}")
        end
      end

      # The manifest at svg-icons/lucide-icons.txt is the source of truth and the
      # matching sprite lives next to it. In non-production environments the
      # sprite is regenerated automatically when the manifest has changed; on
      # production builds the committed sprite is used as-is.
      def self.regenerate_lucide_sprite_if_stale
        return if Rails.env.production? || !LucideSprite.stale?

        LucideSprite.generate!
      rescue LucideSprite::MissingSourceError, LucideSprite::MissingIconError => e
        Rails.logger.warn("[discourse-wireframe] Lucide sprite regen skipped: #{e.message}")
      end
    end
  end
end
