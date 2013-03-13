# A basic plugin for Discourse. Meant to be extended and filled in.
# Most work is delegated to a registry.

class DiscoursePlugin

  attr_reader :registry

  def initialize(registry)
    @registry = registry
  end

  def setup
    # Initialize the plugin here
  end

  # Loads and mixes in the plugin's mixins into the host app's classes.
  # A mixin named "UserMixin" will be included into the "User" class.
  def self.include_mixins
    mixins.each do |mixin|
      original_class = mixin.to_s.demodulize.sub("Mixin", "")
      dependency_file_name = original_class.underscore
      require_dependency(dependency_file_name)
      original_class.constantize.send(:include, mixin)
    end
  end

  # Find the modules defined in the plugin with "Mixin" in their name.
  def self.mixins
    constants.map { |const_name| const_get(const_name) }
             .select { |const| const.class == Module && const.name["Mixin"] }
  end

  def register_js(file, opts={})
    @registry.register_js(file, opts)
  end

  def register_css(file)
    @registry.register_css(file)
  end

  def register_archetype(name, options={})
    @registry.register_archetype(name, options)
  end

  def listen_for(event_name)
    return unless self.respond_to?(event_name)
    DiscourseEvent.on(event_name, &self.method(event_name))
  end

end

