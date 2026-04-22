# frozen_string_literal: true

# name: discourse-workflows
# about: Workflow automation system for Discourse
# meta_topic_id: TODO
# version: 0.1
# authors: Discourse
# url: https://github.com/discourse/discourse-workflows

enabled_site_setting :discourse_workflows_enabled

module ::DiscourseWorkflows
  PLUGIN_NAME = "discourse-workflows"
  TEMPLATES_PATH = File.expand_path("config/templates", __dir__)
end

require_relative "lib/discourse_workflows/engine"

register_asset "stylesheets/common/index.scss"
register_asset "stylesheets/colors.scss", :color_definitions
register_svg_icon "bolt"
register_svg_icon "arrows-split-up-and-left"
register_svg_icon "list"
register_svg_icon "arrow-rotate-right"
register_svg_icon "arrows-turn-to-dots"
register_svg_icon "globe"
register_svg_icon "table"
register_svg_icon "table-cells"
register_svg_icon "expand"
register_svg_icon "magnifying-glass-minus"
register_svg_icon "magnifying-glass-plus"
register_svg_icon "user-check"
register_svg_icon "calendar-days"
register_svg_icon "rectangle-list"
register_svg_icon "shuffle"
register_svg_icon "trash-can"
register_svg_icon "broom"
register_svg_icon "arrow-pointer"
register_svg_icon "note-sticky"
register_svg_icon "palette"
register_svg_icon "reply"
register_svg_icon "triangle-exclamation"
register_svg_icon "clock"
register_svg_icon "comments"
register_svg_icon "pause"
register_svg_icon "user-plus"
register_svg_icon "grip-vertical"
register_svg_icon "arrow-down-a-z"

add_admin_route "discourse_workflows.admin.title", "discourse-workflows", use_new_show_route: true

DiscoursePluginRegistry.define_filtered_register(:discourse_workflows_nodes)
DiscoursePluginRegistry.define_filtered_register(:discourse_workflows_credential_types)

after_initialize do
  nodes_dir = File.join(File.dirname(__FILE__), "lib/discourse_workflows/nodes")
  Dir.glob(File.join(nodes_dir, "**/*.rb")).each { |f| Rails.autoloaders.main.load_file(f) }

  DiscourseWorkflows::NodeType.registered_nodes.each do |node_class|
    DiscoursePluginRegistry.register_discourse_workflows_node(node_class, self)

    next unless node_class.respond_to?(:event_name) && node_class.event_name
    on(node_class.event_name) do |*args|
      DiscourseWorkflows::EventListener.handle(node_class, *args)
    end
  end

  DiscoursePluginRegistry.register_discourse_workflows_credential_type(
    DiscourseWorkflows::CredentialTypes::BasicAuth,
    self,
  )
  DiscoursePluginRegistry.register_discourse_workflows_credential_type(
    DiscourseWorkflows::CredentialTypes::BearerToken,
    self,
  )

  add_to_serializer :site,
                    :topic_admin_button_workflows,
                    include_condition: -> { scope.is_admin? } do
    DiscourseWorkflows::WorkflowDependency.cached_topic_admin_buttons
  end

  on(:site_setting_changed) do |name, old_value, new_value|
    next if name != :discourse_workflows_enabled
    next unless new_value && !old_value

    DiscourseWorkflows::PluginEnableHandler.handle!
  end
end
