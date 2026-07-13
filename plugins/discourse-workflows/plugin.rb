# frozen_string_literal: true

# name: discourse-workflows
# about: Workflow automation system for Discourse
# meta_topic_id: 406990
# version: 0.1
# authors: Discourse
# url: https://github.com/discourse/discourse-workflows

enabled_site_setting :enable_discourse_workflows

module ::DiscourseWorkflows
  PLUGIN_NAME = "discourse-workflows"
  TEMPLATES_PATH = File.expand_path("config/templates", __dir__)
end

require_relative "lib/discourse_workflows/engine"
require_relative "lib/discourse_workflows/plugin_node_registration"

register_asset "stylesheets/common/index.scss"
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
register_svg_icon "trash-can"
register_svg_icon "broom"
register_svg_icon "arrow-pointer"
register_svg_icon "note-sticky"
register_svg_icon "palette"
register_svg_icon "reply"
register_svg_icon "triangle-exclamation"
register_svg_icon "clock"
register_svg_icon "dollar-sign"
register_svg_icon "comments"
register_svg_icon "pause"
register_svg_icon "window-maximize"
register_svg_icon "user-plus"
register_svg_icon "user-minus"
register_svg_icon "grip-vertical"
register_svg_icon "paragraph"
register_svg_icon "arrow-down-a-z"
register_svg_icon "copy"
register_svg_icon "paste"
register_svg_icon "scissors"

add_admin_route "discourse_workflows.admin.title", "discourse-workflows", use_new_show_route: true

DiscoursePluginRegistry.define_filtered_register(:discourse_workflows_nodes)
DiscoursePluginRegistry.define_filtered_register(:discourse_workflows_credential_types)

after_initialize do
  Rails.application.config.filter_parameters += %i[signature]

  add_to_class(:guardian, :can_manage_workflows?) { is_admin? }

  nodes_dir = File.join(File.dirname(__FILE__), "lib/discourse_workflows/nodes")
  Dir.glob(File.join(nodes_dir, "**/*.rb")).each { |f| Rails.autoloaders.main.load_file(f) }

  DiscourseWorkflows::NodeType.registered_nodes.each do |node_class|
    DiscoursePluginRegistry.register_discourse_workflows_node(node_class, self)

    next unless node_class.respond_to?(:event_name) && node_class.event_name
    on(node_class.event_name) do |*args|
      DiscourseWorkflows::EventListener.handle(node_class, *args)
    end
  end

  DiscourseWorkflows.node_registration_ready = true
  DiscourseWorkflows.flush_plugin_node_registrations!
  DiscourseWorkflows::Registry.reset_indexes!

  DiscoursePluginRegistry.register_discourse_workflows_credential_type(
    DiscourseWorkflows::CredentialTypes::BasicAuth,
    self,
  )
  DiscoursePluginRegistry.register_discourse_workflows_credential_type(
    DiscourseWorkflows::CredentialTypes::BearerToken,
    self,
  )
  DiscoursePluginRegistry.register_discourse_workflows_credential_type(
    DiscourseWorkflows::CredentialTypes::HeaderAuth,
    self,
  )

  if defined?(DiscourseAi)
    require_relative "lib/discourse_workflows/ai/tools/base"
    require_relative "lib/discourse_workflows/ai/graph_digest"
    require_relative "lib/discourse_workflows/ai/progress_publisher"
    require_relative "lib/discourse_workflows/ai/tools/workflow_node_catalog"
    require_relative "lib/discourse_workflows/ai/tools/workflow_ai_agent_catalog"
    require_relative "lib/discourse_workflows/ai/tools/workflow_graph_context"
    require_relative "lib/discourse_workflows/ai/tools/workflow_validate_patch"
    require_relative "lib/discourse_workflows/ai/tools/workflow_ask_questions"
    require_relative "lib/discourse_workflows/ai/tools/workflow_resolve_entity"
    require_relative "lib/discourse_workflows/ai/tools/search_chat_channels"
    require_relative "lib/discourse_workflows/ai/tools/workflow_script_context"
    require_relative "lib/discourse_workflows/ai/tools/workflow_validate_script"
    require_relative "lib/discourse_workflows/ai_workflow_author"

    DiscourseAi.register_feature(
      module_name: :discourse_workflows,
      feature: :workflow_authoring,
      agent_klass: DiscourseWorkflows::AiWorkflowAuthor,
      enabled_by_setting: "discourse_workflows_ai_authoring_enabled",
      plugin: self,
    )
  end

  add_to_serializer :site,
                    :topic_admin_button_workflows,
                    include_condition: -> { scope.is_admin? } do
    DiscourseWorkflows::WorkflowDependency.cached_topic_admin_buttons
  end

  add_to_serializer :current_user,
                    :discourse_workflows_user_modal_last_id,
                    include_condition: -> do
                      DiscourseWorkflows::WorkflowDependency.cached_user_modals?
                    end do
    MessageBus.last_id(DiscourseWorkflows::Nodes::Modal::V1.user_channel(object.id))
  end

  on(:site_setting_changed) do |name, old_value, new_value|
    next if name != :enable_discourse_workflows
    next unless new_value && !old_value

    DiscourseWorkflows::PluginEnableHandler.handle!
  end

  # Automatic promotion of an upcoming change does not write the site setting,
  # so :site_setting_changed never fires for it. See UpcomingChanges::NotifyPromotion.
  on(:upcoming_change_enabled) do |name|
    next if name != :enable_discourse_workflows

    # A manual opt-in writes the setting before this event fires, so the
    # :site_setting_changed hook above has already run.
    next if SiteSetting.setting_modified_from_default?(:enable_discourse_workflows)

    DiscourseWorkflows::PluginEnableHandler.handle!
  end
end
