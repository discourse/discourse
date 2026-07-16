# frozen_string_literal: true

module DiscourseAi
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseAi
  end

  # Register an AI-powered feature from another plugin. The feature will
  # appear in the AI features admin page, where admins can select which agent
  # backs it.
  #
  # The agent_klass must be a subclass of {DiscourseAi::Agents::Agent} and
  # implement at minimum `#tools` (returning an array of tool classes) and
  # `#system_prompt` (returning the prompt string).
  #
  # Each tool class must be a subclass of {DiscourseAi::Agents::Tools::Tool}
  # and implement:
  # - `.signature` - returns a hash with `name`, `description`, and `parameters`
  # - `.name` - returns the tool name string
  # - `#invoke` - executes the tool and returns a result hash
  #
  # @example Defining a tool, agent, and registering the feature
  #   class MyPlugin::Tools::RunQuery < DiscourseAi::Agents::Tools::Tool
  #     def self.signature
  #       { name: "run_query", description: "Runs a query", parameters: [] }
  #     end
  #
  #     def self.name
  #       "run_query"
  #     end
  #
  #     def invoke
  #       { result: "ok" }
  #     end
  #   end
  #
  #   class MyPlugin::QueryAgent < DiscourseAi::Agents::Agent
  #     def tools
  #       [MyPlugin::Tools::RunQuery]
  #     end
  #
  #     def system_prompt
  #       "You are a query expert."
  #     end
  #   end
  #
  #   DiscourseAi.register_feature(
  #     module_name: :my_plugin,
  #     feature: :query_generation,
  #     agent_klass: MyPlugin::QueryAgent,
  #     enabled_by_setting: "my_plugin_ai_enabled",
  #     plugin: self,
  #   )
  #
  # @param module_name [Symbol] groups features under a module in the admin UI
  # @param feature [Symbol] the feature name within the module
  # @param agent_klass [Class] a subclass of {DiscourseAi::Agents::Agent}
  # @param enabled_by_setting [String, nil] site setting that gates this feature
  # @param plugin [Plugin::Instance] the plugin instance registering the feature
  def self.register_feature(module_name:, feature:, agent_klass:, enabled_by_setting: nil, plugin:)
    area = "ai-features/#{module_name}"
    plugin.register_site_setting_area(area)

    setting_name = "#{module_name}_#{feature}_agent"
    SiteSetting.send(
      :setting,
      setting_name.to_sym,
      DiscourseAi::Agents::Agent.external_agent_id(agent_klass).to_s,
      type: "enum",
      enum: "DiscourseAi::Configuration::AgentEnumerator",
      depends_on: ["discourse_ai_enabled", enabled_by_setting].compact,
      depends_behavior: "hidden",
      area: area,
    )

    if enabled_by_setting.present?
      key = enabled_by_setting.to_sym
      existing = SiteSetting.areas[key]
      SiteSetting.areas[key] = existing ? (Array.wrap(existing) | [area]) : area
    end

    DiscoursePluginRegistry.register_external_ai_feature(
      {
        module_name: module_name,
        feature: feature,
        agent_klass: agent_klass,
        enabled_by_setting: enabled_by_setting,
        visible: true,
      },
      plugin,
    )
  end

  # Registers a tool from another plugin for an existing agent class. The tool
  # is only available while the registering plugin is enabled.
  def self.register_agent_tool(agent_klass:, tool_klass:, plugin:)
    DiscoursePluginRegistry.register_external_ai_agent_tool(
      { agent_klass: agent_klass, tool_klass: tool_klass },
      plugin,
    )
  end
end
