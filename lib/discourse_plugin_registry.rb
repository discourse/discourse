#
#  A class that handles interaction between a plugin and the Discourse App.
#
class DiscoursePluginRegistry

  class << self
    attr_accessor :javascripts
    attr_accessor :server_side_javascripts
    attr_accessor :admin_javascripts
    attr_accessor :stylesheets
    attr_accessor :mobile_stylesheets
    attr_accessor :desktop_stylesheets
    attr_accessor :sass_variables
    attr_accessor :handlebars
    attr_accessor :custom_html
    attr_accessor :serialized_current_user_fields


    # Default accessor values
    def javascripts
      @javascripts ||= Set.new
    end

    def admin_javascripts
      @admin_javascripts ||= Set.new
    end

    def server_side_javascripts
      @server_side_javascripts ||= Set.new
    end

    def stylesheets
      @stylesheets ||= Set.new
    end

    def mobile_stylesheets
      @mobile_stylesheets ||= Set.new
    end

    def desktop_stylesheets
      @desktop_stylesheets ||= Set.new
    end

    def sass_variables
      @sass_variables ||= Set.new
    end

    def handlebars
      @handlebars ||= Set.new
    end

    def serialized_current_user_fields
      @serialized_current_user_fields ||= Set.new
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

  def self.register_asset(asset, opts=nil)
    if asset =~ /\.js$|\.js\.erb$|\.js\.es6$/
      if opts == :admin
        self.admin_javascripts << asset
      else
        if opts == :server_side
          self.server_side_javascripts << asset
        end
        self.javascripts << asset
      end
    elsif asset =~ /\.css$|\.scss$/
      if opts == :mobile
        self.mobile_stylesheets << asset
      elsif opts == :desktop
        self.desktop_stylesheets << asset
      elsif opts == :variables
        self.sass_variables << asset
      else
        self.stylesheets << asset
      end

    elsif asset =~ /\.hbs$/
      self.handlebars << asset
    elsif asset =~ /\.js\.handlebars$/
      self.handlebars << asset
    end
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

  def mobile_stylesheets
    self.class.mobile_stylesheets
  end

  def desktop_stylesheets
    self.class.desktop_stylesheets
  end

  def sass_variables
    self.class.sass_variables
  end

  def handlebars
    self.class.handlebars
  end

  def self.clear
    self.javascripts = nil
    self.server_side_javascripts = nil
    self.stylesheets = nil
    self.mobile_stylesheets = nil
    self.desktop_stylesheets = nil
    self.sass_variables = nil
    self.handlebars = nil
  end

  def self.reset!
    javascripts.clear
    admin_javascripts.clear
    server_side_javascripts.clear
    stylesheets.clear
    mobile_stylesheets.clear
    desktop_stylesheets.clear
    sass_variables.clear
    serialized_current_user_fields
  end

  def self.setup(plugin_class)
    registry = DiscoursePluginRegistry.new
    plugin = plugin_class.new(registry)
    plugin.setup
  end

end
