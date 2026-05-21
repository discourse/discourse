# frozen_string_literal: true

# name: discourse-visual-editor
# about: Drag-and-drop visual editor for customizing the Discourse UI via the Blocks system
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-visual-editor

register_asset "stylesheets/visual-editor.scss"
# Editor chrome — organizational split from `visual-editor.scss`. Both
# files currently ship to every user; the `stylesheets/admin/` path is
# a naming convention only, NOT an automatic staff gate. Discourse's
# plugin stylesheet pipeline (`lib/discourse.rb:find_plugin_css_assets`)
# doesn't filter by user permission. Per-asset staff gating is tracked
# as a follow-up — see docs/REVISIT.md.
register_asset "stylesheets/admin/visual-editor-chrome.scss"
enabled_site_setting :visual_editor_enabled

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
register_svg_icon "circle-dashed"
register_svg_icon "cube"
register_svg_icon "cubes"
register_svg_icon "down-left-and-up-right-to-center"
register_svg_icon "down-long"
register_svg_icon "grip-lines"
register_svg_icon "heading"
register_svg_icon "object-group"
register_svg_icon "paragraph"
register_svg_icon "table-cells-large"
register_svg_icon "table-columns"
register_svg_icon "triangle-exclamation"
register_svg_icon "up-long"
register_svg_icon "up-right-and-down-left-from-center"
register_svg_icon "wand-magic-sparkles"

module ::DiscourseVisualEditor
  PLUGIN_NAME = "discourse-visual-editor"
end
