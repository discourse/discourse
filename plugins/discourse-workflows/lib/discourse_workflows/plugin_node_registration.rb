# frozen_string_literal: true

module DiscourseWorkflows
  class << self
    attr_writer :node_registration_ready

    def node_registration_ready?
      @node_registration_ready == true
    end

    # A node class belongs to the first plugin that claims it, and claiming it is
    # what subscribes its trigger event. Contributing plugins are flushed before
    # the host registers its own nodes, so a node shipped by another plugin is
    # attributed to that plugin and stops listening when it is disabled.
    def register_node(node_class, plugin)
      return if node_registered?(node_class)

      DiscoursePluginRegistry.register_discourse_workflows_node(node_class, plugin)
      subscribe_node_event(node_class, plugin)
    end

    def register_plugin_node_registration(plugin, registration)
      node_classes =
        if registration.respond_to?(:call)
          plugin.instance_exec(&registration)
        else
          registration
        end

      Array.wrap(node_classes).each { |node_class| register_node(node_class, plugin) }
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

    private

    def node_registered?(node_class)
      DiscoursePluginRegistry._raw_discourse_workflows_nodes.any? do |entry|
        entry[:value] == node_class
      end
    end

    # `Plugin::Instance#on` gates the handler on the owning plugin being enabled,
    # so a node stops listening as soon as its plugin is turned off.
    def subscribe_node_event(node_class, plugin)
      event_name = node_class.event_name if node_class.respond_to?(:event_name)
      return if event_name.blank?

      plugin.on(event_name) { |*args| EventListener.handle(node_class, *args) }
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
