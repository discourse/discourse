#
#  A class that handles interaction between a plugin and the Discourse App.
#
class DiscoursePluginRegistry

  class << self
    attr_writer :javascripts
    attr_writer :admin_javascripts
    attr_writer :stylesheets
    attr_writer :mobile_stylesheets
    attr_writer :desktop_stylesheets
    attr_writer :sass_variables
    attr_writer :handlebars
    attr_writer :serialized_current_user_fields
    attr_writer :seed_data

    attr_accessor :custom_html

    # Default accessor values
    def javascripts
      @javascripts ||= Set.new
    end

    def asset_globs
      @asset_globs ||= Set.new
    end

    def admin_javascripts
      @admin_javascripts ||= Set.new
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

    def seed_data
      @seed_data ||= HashWithIndifferentAccess.new({})
    end
  end

  def register_js(filename, options={})
    # If we have a server side option, add that too.
    self.class.javascripts << filename
  end

  def register_css(filename)
    self.class.stylesheets << filename
  end

  def register_archetype(name, options={})
    Archetype.register(name, options)
  end

  def self.register_glob(root, extension, options=nil)
    self.asset_globs << [root, extension, options || {}]
  end

  def self.each_globbed_asset(each_options=nil)
    each_options ||= {}

    self.asset_globs.each do |g|
      root, ext, options = *g

      if options[:admin]
        next unless each_options[:admin]
      else
        next if each_options[:admin]
      end

      Dir.glob("#{root}/**/*") do |f|
        yield f, ext
      end
    end
  end

  def self.register_asset(asset, opts=nil)
    if asset =~ /\.js$|\.js\.erb$|\.js\.es6$/
      if opts == :admin
        self.admin_javascripts << asset
      else
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

  def self.register_seed_data(key, value)
    self.seed_data[key] = value
  end

  def javascripts
    self.class.javascripts
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
    self.stylesheets = nil
    self.mobile_stylesheets = nil
    self.desktop_stylesheets = nil
    self.sass_variables = nil
    self.handlebars = nil
  end

  def self.reset!
    javascripts.clear
    admin_javascripts.clear
    stylesheets.clear
    mobile_stylesheets.clear
    desktop_stylesheets.clear
    sass_variables.clear
    serialized_current_user_fields
    asset_globs.clear
  end

  def self.setup(plugin_class)
    registry = DiscoursePluginRegistry.new
    plugin = plugin_class.new(registry)
    plugin.setup
  end

end
