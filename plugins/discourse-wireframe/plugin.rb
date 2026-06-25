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

# Plugin-API registrations are grouped by concern in setup modules under
# `lib/discourse_wireframe/plugin_setup/`. Keep this file a short manifest: do
# NOT add `register_*`, `on(...)`, `add_to_serializer`, etc. directly here.
# Instead add the call to the relevant `PluginSetup` module (or create a new one
# for a new concern) and wire it with a `<Module>.apply(self)` line below. Each
# module's `apply` receives this plugin instance and runs its DSL calls on it.
require_relative "lib/discourse_wireframe/plugin_setup/icons"
require_relative "lib/discourse_wireframe/plugin_setup/draft_cleanup"

DiscourseWireframe::PluginSetup::Icons.apply(self)
DiscourseWireframe::PluginSetup::DraftCleanup.apply(self)
