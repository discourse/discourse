#
#  A class that handles interaction between a plugin and the Discourse App.
#
class DiscoursePluginRegistry

  class << self
    attr_accessor :javascripts
    attr_accessor :server_side_javascripts
    attr_accessor :stylesheets
    attr_accessor :handlebars

    # Default accessor values
    def javascripts
      @javascripts ||= Set.new
    end

    def server_side_javascripts
      @server_side_javascripts ||= Set.new
    end

    def stylesheets
      @stylesheets ||= Set.new
    end

    def handlebars
      @handlebars ||= Set.new
    end
  end

  def register_js(filename, options={})
    # If we have a server side option, add that too.
    self.class.server_side_javascripts << options[:server_side] if options[:server_side].present?
    self.class.javascripts << filename
  end

  def register_css(filename)
    self.class.stylesheets << filename
  end

  def register_archetype(name, options={})
    Archetype.register(name, options)
  end

  def javascripts
    self.class.javascripts
  end

  def server_side_javascripts
    self.class.server_side_javascripts
  end

  def stylesheets
    self.class.stylesheets
  end

  def handlebars
    self.class.handlebars
  end

  def self.clear
    self.javascripts = nil
    self.server_side_javascripts = nil
    self.stylesheets = nil
    self.handlebars = nil
  end

  def self.setup(plugin_class)
    registry = DiscoursePluginRegistry.new
    plugin = plugin_class.new(registry)
    plugin.setup
  end

end
