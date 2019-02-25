#
#  A class that handles interaction between a plugin and the Discourse App.
#
class DiscoursePluginRegistry

  class << self
    attr_writer :javascripts
    attr_writer :auth_providers
    attr_writer :service_workers
    attr_writer :admin_javascripts
    attr_writer :stylesheets
    attr_writer :mobile_stylesheets
    attr_writer :desktop_stylesheets
    attr_writer :sass_variables
    attr_writer :handlebars
    attr_writer :serialized_current_user_fields
    attr_writer :seed_data
    attr_writer :svg_icons
    attr_writer :locales
    attr_accessor :custom_html

    def plugins
      @plugins ||= []
    end

    # Default accessor values
    def javascripts
      @javascripts ||= Set.new
    end

    def auth_providers
      @auth_providers ||= Set.new
    end

    def service_workers
      @service_workers ||= Set.new
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

    def svg_icons
      @svg_icons ||= []
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

    def locales
      @locales ||= HashWithIndifferentAccess.new({})
    end

    def html_builders
      @html_builders ||= {}
    end

    def seed_path_builders
      @seed_path_builders ||= Set.new
    end

    def vendored_pretty_text
      @vendored_pretty_text ||= Set.new
    end

    def vendored_core_pretty_text
      @vendored_core_pretty_text ||= Set.new
    end
  end

  def self.register_auth_provider(auth_provider)
    self.auth_providers << auth_provider
  end

  def register_js(filename, options = {})
    # If we have a server side option, add that too.
    self.class.javascripts << filename
  end

  def self.register_service_worker(filename, options = {})
    self.service_workers << filename
  end

  def self.register_svg_icon(icon)
    self.svg_icons << icon
  end

  def register_css(filename)
    self.class.stylesheets << filename
  end

  def self.register_locale(locale, options = {})
    self.locales[locale] = options
  end

  def register_archetype(name, options = {})
    Archetype.register(name, options)
  end

  def self.register_glob(root, extension, options = nil)
    self.asset_globs << [root, extension, options || {}]
  end

  def self.each_globbed_asset(each_options = nil)
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

  JS_REGEX = /\.js$|\.js\.erb$|\.js\.es6|\.js\.no-module\.es6$/
  HANDLEBARS_REGEX = /\.hbs$|\.js\.handlebars$/

  def self.register_asset(asset, opts = nil)
    if asset =~ JS_REGEX
      if opts == :admin
        self.admin_javascripts << asset
      elsif opts == :vendored_pretty_text
        self.vendored_pretty_text << asset
      elsif opts == :vendored_core_pretty_text
        self.vendored_core_pretty_text << asset
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
    elsif asset =~ HANDLEBARS_REGEX
      self.handlebars << asset
    end
  end

  def self.register_seed_data(key, value)
    self.seed_data[key] = value
  end

  def self.register_seed_path_builder(&block)
    seed_path_builders << block
  end

  def self.register_html_builder(name, &block)
    html_builders[name] ||= []
    html_builders[name] << block
  end

  def self.build_html(name, ctx = nil)
    builders = html_builders[name] || []
    builders.map { |b| b.call(ctx) }.join("\n").html_safe
  end

  def self.seed_paths
    result = SeedFu.fixture_paths.dup
    unless Rails.env.test? && ENV['LOAD_PLUGINS'] != "1"
      seed_path_builders.each { |b| result += b.call }
    end
    result.uniq
  end

  VENDORED_CORE_PRETTY_TEXT_MAP = {
    "moment.js" => "lib/javascripts/moment.js",
    "moment-timezone.js" => "lib/javascripts/moment-timezone-with-data.js"
  }
  def self.core_asset_for_name(name)
    asset = VENDORED_CORE_PRETTY_TEXT_MAP[name]
    raise KeyError, "Asset #{name} not found in #{VENDORED_CORE_PRETTY_TEXT_MAP}" unless asset
    asset
  end

  def locales
    self.class.locales
  end

  def javascripts
    self.class.javascripts
  end

  def auth_providers
    self.class.auth_providers
  end

  def service_workers
    self.class.service_workers
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
    self.auth_providers = nil
    self.service_workers = nil
    self.stylesheets = nil
    self.mobile_stylesheets = nil
    self.desktop_stylesheets = nil
    self.sass_variables = nil
    self.handlebars = nil
    self.locales = nil
  end

  def self.reset!
    javascripts.clear
    auth_providers.clear
    service_workers.clear
    admin_javascripts.clear
    stylesheets.clear
    mobile_stylesheets.clear
    desktop_stylesheets.clear
    sass_variables.clear
    serialized_current_user_fields
    asset_globs.clear
    html_builders.clear
    vendored_pretty_text.clear
    vendored_core_pretty_text.clear
    seed_path_builders.clear
    locales.clear
  end

  def self.setup(plugin_class)
    registry = DiscoursePluginRegistry.new
    plugin = plugin_class.new(registry)
    plugin.setup
  end

end
