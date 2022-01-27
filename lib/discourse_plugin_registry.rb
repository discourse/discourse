# frozen_string_literal: true

#
#  A class that handles interaction between a plugin and the Discourse App.
#
class DiscoursePluginRegistry

  # Shortcut to create new register in the plugin registry
  #   - Register is created in a class variable using the specified name/type
  #   - Defines singleton method to access the register
  #   - Defines instance method as a shortcut to the singleton method
  #   - Automatically deletes the register on ::clear!
  def self.define_register(register_name, type)
    @@register_names ||= Set.new
    @@register_names << register_name

    define_singleton_method(register_name) do
      instance_variable_get(:"@#{register_name}") ||
        instance_variable_set(:"@#{register_name}", type.new)
    end

    define_method(register_name) do
      self.class.public_send(register_name)
    end
  end

  # Create a new register (see `define_register`) with some additions:
  #   - Register is created in a class variable using the specified name/type
  #   - Defines singleton method to access the register
  #   - Defines instance method as a shortcut to the singleton method
  #   - Automatically deletes the register on ::clear!
  def self.define_filtered_register(register_name)
    define_register(register_name, Array)

    singleton_class.alias_method :"_raw_#{register_name}", :"#{register_name}"

    define_singleton_method(register_name) do
      unfiltered = public_send(:"_raw_#{register_name}")
      unfiltered
        .filter { |v| v[:plugin].enabled? }
        .map { |v| v[:value] }
        .uniq
    end

    define_singleton_method("register_#{register_name.to_s.singularize}") do |value, plugin|
      public_send(:"_raw_#{register_name}") << { plugin: plugin, value: value }
    end
  end

  define_register :javascripts, Set
  define_register :auth_providers, Set
  define_register :service_workers, Set
  define_register :admin_javascripts, Set
  define_register :stylesheets, Hash
  define_register :mobile_stylesheets, Hash
  define_register :desktop_stylesheets, Hash
  define_register :color_definition_stylesheets, Hash
  define_register :handlebars, Set
  define_register :serialized_current_user_fields, Set
  define_register :seed_data, HashWithIndifferentAccess
  define_register :locales, HashWithIndifferentAccess
  define_register :svg_icons, Set
  define_register :custom_html, Hash
  define_register :asset_globs, Set
  define_register :html_builders, Hash
  define_register :seed_path_builders, Set
  define_register :vendored_pretty_text, Set
  define_register :vendored_core_pretty_text, Set
  define_register :seedfu_filter, Set
  define_register :demon_processes, Set
  define_register :groups_callback_for_users_search_controller_action, Hash

  define_filtered_register :staff_user_custom_fields
  define_filtered_register :public_user_custom_fields

  define_filtered_register :self_editable_user_custom_fields
  define_filtered_register :staff_editable_user_custom_fields

  define_filtered_register :editable_group_custom_fields
  define_filtered_register :group_params

  define_filtered_register :topic_thumbnail_sizes

  define_filtered_register :api_parameter_routes
  define_filtered_register :api_key_scope_mappings
  define_filtered_register :user_api_key_scope_mappings

  define_filtered_register :permitted_bulk_action_parameters
  define_filtered_register :reviewable_params
  define_filtered_register :reviewable_score_links

  define_filtered_register :presence_channel_prefixes

  define_filtered_register :push_notification_filters

  define_filtered_register :notification_consolidation_plans

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

  def register_css(filename, plugin_directory_name)
    self.class.stylesheets[plugin_directory_name] ||= Set.new
    self.class.stylesheets[plugin_directory_name] << filename
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

      Dir.glob("#{root}/**/*.#{ext}") do |f|
        yield f
      end
    end
  end

  JS_REGEX = /\.js$|\.js\.erb$|\.js\.es6$/
  HANDLEBARS_REGEX = /\.(hb[rs]|js\.handlebars)$/

  def self.register_asset(asset, opts = nil, plugin_directory_name = nil)
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
        self.mobile_stylesheets[plugin_directory_name] ||= Set.new
        self.mobile_stylesheets[plugin_directory_name] << asset
      elsif opts == :desktop
        self.desktop_stylesheets[plugin_directory_name] ||= Set.new
        self.desktop_stylesheets[plugin_directory_name] << asset
      elsif opts == :color_definitions
        self.color_definition_stylesheets[plugin_directory_name] = asset
      else
        self.stylesheets[plugin_directory_name] ||= Set.new
        self.stylesheets[plugin_directory_name] << asset
      end
    elsif asset =~ HANDLEBARS_REGEX
      self.handlebars << asset
    end
  end

  def self.stylesheets_exists?(plugin_directory_name, target = nil)
    case target
    when :desktop
      self.desktop_stylesheets[plugin_directory_name].present?
    when :mobile
      self.mobile_stylesheets[plugin_directory_name].present?
    else
      self.stylesheets[plugin_directory_name].present?
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

  def self.register_seedfu_filter(filter = nil)
    self.seedfu_filter << filter
  end

  VENDORED_CORE_PRETTY_TEXT_MAP = {
    "moment.js" => "vendor/assets/javascripts/moment.js",
    "moment-timezone.js" => "vendor/assets/javascripts/moment-timezone-with-data.js"
  }
  def self.core_asset_for_name(name)
    asset = VENDORED_CORE_PRETTY_TEXT_MAP[name]
    raise KeyError, "Asset #{name} not found in #{VENDORED_CORE_PRETTY_TEXT_MAP}" unless asset
    asset
  end

  def self.reset!
    @@register_names.each do |name|
      instance_variable_set(:"@#{name}", nil)
    end
  end

  def self.reset_register!(register_name)
    found_register = @@register_names.detect { |name| name == register_name }

    if found_register
      instance_variable_set(:"@#{found_register}", nil)
    end
  end
end
