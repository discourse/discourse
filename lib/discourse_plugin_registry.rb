# frozen_string_literal: true

#
#  A class that handles interaction between a plugin and the Discourse App.
#
class DiscoursePluginRegistry
  @@register_names = Set.new

  # Plugins often need to be able to register additional handlers, data, or
  # classes that will be used by core classes. This should be used if you
  # need to control which type the registry is, and if it doesn't need to
  # be removed if the plugin is disabled.
  #
  # Shortcut to create new register in the plugin registry
  #   - Register is created in a class variable using the specified name/type
  #   - Defines singleton method to access the register
  #   - Defines instance method as a shortcut to the singleton method
  #   - Automatically deletes the register on registry.reset!
  def self.define_register(register_name, type)
    return if respond_to?(register_name)
    @@register_names << register_name

    define_singleton_method(register_name) do
      instance_variable_get(:"@#{register_name}") ||
        instance_variable_set(:"@#{register_name}", type.new)
    end

    define_method(register_name) { self.class.public_send(register_name) }
  end

  # Plugins often need to add values to a list, and we need to filter those
  # lists at runtime to ignore values from disabled plugins. Unlike define_register,
  # the type of the register cannot be defined, and is always Array.
  #
  # Create a new register (see `define_register`) with some additions:
  #   - Register is created in a class variable using the specified name/type
  #   - Defines singleton method to access the register
  #   - Defines instance method as a shortcut to the singleton method
  #   - Automatically deletes the register on registry.reset!
  def self.define_filtered_register(register_name)
    return if respond_to?(register_name)
    define_register(register_name, Array)

    singleton_class.alias_method :"_raw_#{register_name}", :"#{register_name}"

    define_singleton_method(register_name) do
      public_send(:"_raw_#{register_name}").filter_map { |h| h[:value] if h[:plugin].enabled? }.uniq
    end

    define_singleton_method("register_#{register_name.to_s.singularize}") do |value, plugin|
      public_send(:"_raw_#{register_name}") << { plugin: plugin, value: value }
    end
  end

  define_register :javascripts, Set
  define_register :auth_providers, Set
  define_register :service_workers, Set
  define_register :stylesheets, Hash
  define_register :mobile_stylesheets, Hash
  define_register :desktop_stylesheets, Hash
  define_register :color_definition_stylesheets, Hash
  define_register :serialized_current_user_fields, Set
  define_register :seed_data, HashWithIndifferentAccess
  define_register :locales, HashWithIndifferentAccess
  define_register :svg_icons, Set
  define_register :custom_html, Hash
  define_register :html_builders, Hash
  define_register :seed_path_builders, Set
  define_register :vendored_pretty_text, Set
  define_register :vendored_core_pretty_text, Set
  define_register :seedfu_filter, Set
  define_register :demon_processes, Set
  define_register :groups_callback_for_users_search_controller_action, Hash
  define_register :mail_pollers, Set
  define_register :site_setting_areas, Set
  define_register :discourse_dev_populate_reviewable_types, Set

  define_filtered_register :staff_user_custom_fields
  define_filtered_register :public_user_custom_fields

  define_filtered_register :staff_editable_topic_custom_fields
  define_filtered_register :public_editable_topic_custom_fields

  define_filtered_register :self_editable_user_custom_fields
  define_filtered_register :staff_editable_user_custom_fields

  define_filtered_register :editable_group_custom_fields
  define_filtered_register :group_params

  define_filtered_register :topic_thumbnail_sizes
  define_filtered_register :topic_preloader_associations

  define_filtered_register :api_parameter_routes
  define_filtered_register :api_key_scope_mappings
  define_filtered_register :user_api_key_scope_mappings

  define_filtered_register :permitted_bulk_action_parameters
  define_filtered_register :reviewable_params
  define_filtered_register :reviewable_score_links

  define_filtered_register :presence_channel_prefixes

  define_filtered_register :email_notification_filters
  define_filtered_register :push_notification_filters

  define_filtered_register :notification_consolidation_plans

  define_filtered_register :email_unsubscribers

  define_filtered_register :user_destroyer_on_content_deletion_callbacks

  define_filtered_register :hashtag_autocomplete_data_sources
  define_filtered_register :hashtag_autocomplete_contextual_type_priorities

  define_filtered_register :search_groups_set_query_callbacks

  define_filtered_register :stats
  define_filtered_register :bookmarkables

  define_filtered_register :list_suggested_for_providers

  define_filtered_register :post_action_notify_user_handlers

  define_filtered_register :post_strippers

  define_filtered_register :problem_checks

  define_filtered_register :flag_applies_to_types

  define_filtered_register :custom_filter_mappings

  def self.register_auth_provider(auth_provider)
    self.auth_providers << auth_provider
  end

  def self.register_mail_poller(mail_poller)
    self.mail_pollers << mail_poller
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

  JS_REGEX = /\.js$|\.js\.erb$|\.js\.es6\z/

  def self.register_asset(asset, opts = nil, plugin_directory_name = nil)
    if asset =~ JS_REGEX
      if opts == :vendored_pretty_text
        self.vendored_pretty_text << asset
      elsif opts == :vendored_core_pretty_text
        self.vendored_core_pretty_text << asset
      else
        self.javascripts << asset
      end
    elsif asset =~ /\.css$|\.scss\z/
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
    unless Rails.env.test? && ENV["LOAD_PLUGINS"] != "1"
      seed_path_builders.each { |b| result += b.call }
    end
    result.uniq
  end

  def self.register_seedfu_filter(filter = nil)
    self.seedfu_filter << filter
  end

  VENDORED_CORE_PRETTY_TEXT_MAP = {
    "moment.js" => "vendor/assets/javascripts/moment.js",
    "moment-timezone.js" => "vendor/assets/javascripts/moment-timezone-with-data.js",
  }
  def self.core_asset_for_name(name)
    asset = VENDORED_CORE_PRETTY_TEXT_MAP[name]
    raise KeyError, "Asset #{name} not found in #{VENDORED_CORE_PRETTY_TEXT_MAP}" unless asset
    asset
  end

  def self.clear_modifiers!
    if Rails.env.test? && GlobalSetting.load_plugins?
      raise "Clearing modifiers during a plugin spec run will affect all future specs. Use unregister_modifier instead."
    end
    @modifiers = nil
  end

  def self.register_modifier(plugin_instance, name, &blk)
    @modifiers ||= {}
    modifiers = @modifiers[name] ||= []
    modifiers << [plugin_instance, blk]
  end

  def self.unregister_modifier(plugin_instance, name, &blk)
    raise "unregister_modifier can only be used in tests" if !Rails.env.test?

    modifiers_for_name = @modifiers&.[](name)
    raise "no #{name} modifiers found" if !modifiers_for_name

    i = modifiers_for_name.find_index { |info| info == [plugin_instance, blk] }
    raise "no modifier found for that plugin/block combination" if !i

    modifiers_for_name.delete_at(i)
  end

  def self.apply_modifier(name, arg, *more_args)
    return arg if !@modifiers

    registered_modifiers = @modifiers[name]
    return arg if !registered_modifiers

    # iterate as fast as possible to minimize cost (avoiding each)
    # also erases one stack frame
    length = registered_modifiers.length
    index = 0
    while index < length
      plugin_instance, block = registered_modifiers[index]
      arg = block.call(arg, *more_args) if plugin_instance.enabled?

      index += 1
    end

    arg
  end

  def self.reset!
    @@register_names.each { |name| instance_variable_set(:"@#{name}", nil) }
    clear_modifiers!
  end

  def self.reset_register!(register_name)
    found_register = @@register_names.detect { |name| name == register_name }

    instance_variable_set(:"@#{found_register}", nil) if found_register
  end
end
