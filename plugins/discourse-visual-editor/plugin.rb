# frozen_string_literal: true

# name: discourse-visual-editor
# about: Drag-and-drop visual editor for customizing the Discourse UI via the Blocks system
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-visual-editor

register_asset "stylesheets/visual-editor.scss"
enabled_site_setting :visual_editor_enabled

module ::DiscourseVisualEditor
  PLUGIN_NAME = "discourse-visual-editor"
end
