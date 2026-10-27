# frozen_string_literal: true

module DiscourseWorkflows
  class Template::List
    include Service::Base

    policy :can_manage_workflows, class_name: Policy::CanManageWorkflows
    model :templates, optional: true

    private

    def fetch_templates
      nodes = Hash.new { |cache, identifier| cache[identifier] = node_info(identifier) }

      DiscourseWorkflows::TemplateStore.summaries.each do |summary|
        infos = summary[:node_types].map { |identifier| nodes[identifier] }

        summary[:plugins] = infos.filter_map { |info| info[:plugin] }.uniq
        summary[:missing_requirements] = infos.filter_map { |info| info[:requirement] }.uniq
        summary[:available] = summary[:plugins].all? { |plugin| plugin[:enabled] } &&
          summary[:missing_requirements].empty?
      end
    end

    def node_info(identifier)
      klass = Registry.latest_node_type(identifier, include_disabled_plugins: true)
      plugin = contributing_plugin(klass)

      {
        plugin: plugin && { name: plugin.humanized_name, enabled: plugin.enabled? },
        requirement: requirement_for(identifier, klass, plugin),
      }
    end

    def contributing_plugin(klass)
      plugin = klass && Registry.plugin_for(klass)
      plugin unless plugin&.name == DiscourseWorkflows::PLUGIN_NAME
    end

    def requirement_for(identifier, klass, plugin)
      return if klass&.available?
      return if plugin && !plugin.enabled?

      { node_type: identifier, reason_key: klass&.unavailable_reason_key }
    end
  end
end
