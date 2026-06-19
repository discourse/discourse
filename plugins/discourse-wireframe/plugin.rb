# frozen_string_literal: true

# name: discourse-wireframe
# about: Drag-and-drop wireframe for customizing the Discourse UI via the Blocks system
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-wireframe

register_asset "stylesheets/wireframe.scss"
register_asset "stylesheets/admin/wireframe-chrome.scss", :admin

enabled_site_setting :wireframe_enabled

module ::DiscourseWireframe
  PLUGIN_NAME = "discourse-wireframe"
end

require_relative "lib/discourse_wireframe/engine"

# Icons used by block-metadata `icon:` fields and inspector UI that
# aren't in the default SVG subset. Without these the rendered icon
# is replaced by a placeholder square and the console logs a warning
# per missing glyph.
register_svg_icon "align-center"
register_svg_icon "align-right"
register_svg_icon "arrow-line-left"
register_svg_icon "arrows-left-right"
register_svg_icon "arrows-up-down"
register_svg_icon "border-none"
register_svg_icon "bullhorn"
register_svg_icon "circle-dashed"
register_svg_icon "circle-half-stroke"
register_svg_icon "cube"
register_svg_icon "cubes"
register_svg_icon "down-left-and-up-right-to-center"
register_svg_icon "down-long"
register_svg_icon "fire"
register_svg_icon "folder-tree"
register_svg_icon "grip-lines"
register_svg_icon "heading"
register_svg_icon "object-group"
register_svg_icon "paragraph"
register_svg_icon "photo-film"
register_svg_icon "table-cells-large"
register_svg_icon "table-columns"
register_svg_icon "triangle-exclamation"
register_svg_icon "up-long"
register_svg_icon "up-right-and-down-left-from-center"
register_svg_icon "wand-magic-sparkles"

require_relative "lib/discourse_wireframe/lucide_sprite"

# Lucide icons. The manifest at svg-icons/lucide-icons.txt is the
# source of truth and the matching sprite lives next to it. In
# non-production environments the sprite is regenerated automatically
# when the manifest has changed; on production builds the committed
# sprite is used as-is. Each manifest entry is registered with a `wf-`
# prefix so it can be referenced as `wf-<name>` from templates.
if !Rails.env.production? && DiscourseWireframe::LucideSprite.stale?
  begin
    DiscourseWireframe::LucideSprite.generate!
  rescue DiscourseWireframe::LucideSprite::MissingSourceError,
         DiscourseWireframe::LucideSprite::MissingIconError => e
    Rails.logger.warn("[discourse-wireframe] Lucide sprite regen skipped: #{e.message}")
  end
end

DiscourseWireframe::LucideSprite.manifest_names.each do |name|
  register_svg_icon "#{DiscourseWireframe::LucideSprite::ICON_PREFIX}#{name}"
end
