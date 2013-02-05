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

  # Find the modules in our class with the name mixin, then include them in the appropriate places
  # automagically.
  def self.include_mixins
    modules = constants.collect {|const_name| const_get(const_name)}.select {|const| const.class == Module}
    unless modules.empty?
      modules.each do |m|
        original_class = m.to_s.sub("#{self.name}::", '').sub("Mixin", "")
        dependency_file_name = original_class.underscore
        require_dependency(dependency_file_name)  
        original_class.constantize.send(:include, m)
      end
    end
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

