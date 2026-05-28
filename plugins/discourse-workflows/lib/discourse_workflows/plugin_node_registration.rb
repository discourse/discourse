# frozen_string_literal: true

module DiscourseWorkflows
  class << self
    attr_writer :node_registration_ready

    def node_registration_ready?
      @node_registration_ready == true
    end

    def register_plugin_node_registration(plugin, registration)
      node_classes =
        if registration.respond_to?(:call)
          plugin.instance_exec(&registration)
        else
          registration
        end

      Array
        .wrap(node_classes)
        .each do |node_class|
          DiscoursePluginRegistry.register_discourse_workflows_node(node_class, plugin)
        end
    end

    def flush_plugin_node_registrations!
      Discourse.plugins.each do |plugin|
        next unless plugin.respond_to?(:discourse_workflows_node_registrations)

        plugin.discourse_workflows_node_registrations.each do |registration|
          register_plugin_node_registration(plugin, registration)
        end
        plugin.discourse_workflows_node_registrations.clear
      end
    end
  end
end

class Plugin::Instance
  def register_discourse_workflows_node(node_class = nil, &block)
    raise ArgumentError, "Provide a node class or a block, not both" if node_class && block
    raise ArgumentError, "Provide a node class or a block" if !node_class && !block

    register_discourse_workflows_node_cache_reset!

    registration = block || node_class
    if DiscourseWorkflows.node_registration_ready?
      DiscourseWorkflows.register_plugin_node_registration(self, registration)
    else
      discourse_workflows_node_registrations << registration
    end
  end

  def discourse_workflows_node_registrations
    @discourse_workflows_node_registrations ||= []
  end

  private

  def register_discourse_workflows_node_cache_reset!
    return if @discourse_workflows_node_cache_reset_registered
    return if enabled_site_setting.blank?

    @discourse_workflows_node_cache_reset_registered = true
    @discourse_workflows_node_cache_reset_handler =
      on_enabled_change { DiscourseWorkflows::Registry.reset_indexes! }
  end
end
