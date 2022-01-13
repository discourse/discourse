# frozen_string_literal: true

require 'digest/sha1'
require 'fileutils'
require_dependency 'plugin/metadata'
require_dependency 'auth'

class Plugin::CustomEmoji
  CACHE_KEY ||= "plugin-emoji"
  def self.cache_key
    @@cache_key ||= CACHE_KEY
  end

  def self.emojis
    @@emojis ||= {}
  end

  def self.clear_cache
    @@cache_key = CACHE_KEY
    @@emojis = {}
    @@translations = {}
  end

  def self.register(name, url, group = Emoji::DEFAULT_GROUP)
    @@cache_key = Digest::SHA1.hexdigest(cache_key + name + group)[0..10]
    new_group = emojis[group] || {}
    new_group[name] = url
    emojis[group] = new_group
  end

  def self.unregister(name, group = Emoji::DEFAULT_GROUP)
    emojis[group].delete(name)
  end

  def self.translations
    @@translations ||= {}
  end

  def self.translate(from, to)
    @@cache_key = Digest::SHA1.hexdigest(cache_key + from)[0..10]
    translations[from] = to
  end
end

class Plugin::Instance

  attr_accessor :path, :metadata
  attr_reader :admin_route

  # Memoized array readers
  [:assets,
   :color_schemes,
   :before_auth_initializers,
   :initializers,
   :javascripts,
   :locales,
   :service_workers,
   :styles,
   :themes,
   :csp_extensions,
   :asset_filters
 ].each do |att|
    class_eval %Q{
      def #{att}
        @#{att} ||= []
      end
    }
  end

  # If plugins provide `transpile_js: true` in their metadata we will
  # transpile regular JS files in the assets folders. Going forward,
  # all plugins should do this.
  def transpile_js
    metadata.try(:transpile_js) == "true"
  end

  def seed_data
    @seed_data ||= HashWithIndifferentAccess.new({})
  end

  def seed_fu_filter(filter = nil)
    @seed_fu_filter = filter
  end

  def self.find_all(parent_path)
    [].tap { |plugins|
      # also follows symlinks - http://stackoverflow.com/q/357754
      Dir["#{parent_path}/*/plugin.rb"].sort.each do |path|
        source = File.read(path)
        metadata = Plugin::Metadata.parse(source)
        plugins << self.new(metadata, path)
      end
    }
  end

  def initialize(metadata = nil, path = nil)
    @metadata = metadata
    @path = path
    @idx = 0
  end

  def register_anonymous_cache_key(key, &block)
    key_method = "key_#{key}"
    add_to_class(Middleware::AnonymousCache::Helper, key_method, &block)
    Middleware::AnonymousCache.cache_key_segments[key] = key_method
    Middleware::AnonymousCache.compile_key_builder
  end

  def add_admin_route(label, location)
    @admin_route = { label: label, location: location }
  end

  def enabled?
    @enabled_site_setting ? SiteSetting.get(@enabled_site_setting) : true
  end

  delegate :name, to: :metadata

  def add_to_serializer(serializer, attr, define_include_method = true, &block)
    reloadable_patch do |plugin|
      base = "#{serializer.to_s.classify}Serializer".constantize rescue "#{serializer.to_s}Serializer".constantize

      # we have to work through descendants cause serializers may already be baked and cached
      ([base] + base.descendants).each do |klass|
        unless attr.to_s.start_with?("include_")
          klass.attributes(attr)

          if define_include_method
            # Don't include serialized methods if the plugin is disabled
            klass.public_send(:define_method, "include_#{attr}?") { plugin.enabled? }
          end
        end

        klass.public_send(:define_method, attr, &block)
      end
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def add_report(name, &block)
    reloadable_patch do |plugin|
      Report.add_report(name, &block)
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def replace_flags(settings: ::FlagSettings.new, score_type_names: [])
    next_flag_id = ReviewableScore.types.values.max + 1

    yield(settings, next_flag_id) if block_given?

    reloadable_patch do |plugin|
      ::PostActionType.replace_flag_settings(settings)
      ::ReviewableScore.reload_types
      ::ReviewableScore.add_new_types(score_type_names)
    end
  end

  def whitelist_staff_user_custom_field(field)
    Discourse.deprecate("whitelist_staff_user_custom_field is deprecated, use the allow_staff_user_custom_field.", drop_from: "2.6", raise_error: true)
    allow_staff_user_custom_field(field)
  end

  def allow_staff_user_custom_field(field)
    DiscoursePluginRegistry.register_staff_user_custom_field(field, self)
  end

  def whitelist_public_user_custom_field(field)
    Discourse.deprecate("whitelist_public_user_custom_field is deprecated, use the allow_public_user_custom_field.", drop_from: "2.6", raise_error: true)
    allow_public_user_custom_field(field)
  end

  def allow_public_user_custom_field(field)
    DiscoursePluginRegistry.register_public_user_custom_field(field, self)
  end

  def register_editable_user_custom_field(field, staff_only: false)
    if staff_only
      DiscoursePluginRegistry.register_staff_editable_user_custom_field(field, self)
    else
      DiscoursePluginRegistry.register_self_editable_user_custom_field(field, self)
    end
  end

  def register_editable_group_custom_field(field)
    DiscoursePluginRegistry.register_editable_group_custom_field(field, self)
  end

  # Allows to define custom search order. Example usage:
  #   Search.advanced_order(:chars) do |posts|
  #     posts.reorder("(SELECT LENGTH(raw) FROM posts WHERE posts.topic_id = subquery.topic_id) DESC")
  #   end
  def register_search_advanced_order(trigger, &block)
    Search.advanced_order(trigger, &block)
  end

  # Allows to define custom search filters. Example usage:
  #   Search.advanced_filter(/^min_chars:(\d+)$/) do |posts, match|
  #     posts.where("(SELECT LENGTH(p2.raw) FROM posts p2 WHERE p2.id = posts.id) >= ?", match.to_i)
  #   end
  def register_search_advanced_filter(trigger, &block)
    Search.advanced_filter(trigger, &block)
  end

  # Allows to define TopicView posts filters. Example usage:
  #   TopicView.advanced_filter do |posts, opts|
  #     posts.where(wiki: true)
  #   end
  def register_topic_view_posts_filter(trigger, &block)
    TopicView.add_custom_filter(trigger, &block)
  end

  # Allows to add more user IDs to the list of preloaded users. This can be
  # useful to efficiently change the list of posters or participants.
  # Example usage:
  #   register_topic_list_preload_user_ids do |topics, user_ids, topic_list|
  #     user_ids << Discourse::SYSTEM_USER_ID
  #   end
  def register_topic_list_preload_user_ids(&block)
    TopicList.on_preload_user_ids(&block)
  end

  # Allow to eager load additional tables in Search. Useful to avoid N+1 performance problems.
  # Example usage:
  #   register_search_topic_eager_load do |opts|
  #     %i(example_table)
  #   end
  # OR
  #   register_search_topic_eager_load(%i(example_table))
  def register_search_topic_eager_load(tables = nil, &block)
    Search.custom_topic_eager_load(tables, &block)
  end

  # Request a new size for topic thumbnails
  # Will respect plugin enabled setting is enabled
  # Size should be an array with two elements [max_width, max_height]
  def register_topic_thumbnail_size(size)
    if !(size.kind_of?(Array) && size.length == 2)
      raise ArgumentError.new("Topic thumbnail dimension is not valid")
    end
    DiscoursePluginRegistry.register_topic_thumbnail_size(size, self)
  end

  # Register a callback to add custom payload to Site#categories
  # Example usage:
  #   register_site_categories_callback do |categories|
  #     categories.each do |category|
  #       category[:some_field] = 'test'
  #     end
  #   end
  def register_site_categories_callback(&block)
    Site.add_categories_callbacks(&block)
  end

  def custom_avatar_column(column)
    reloadable_patch do |plugin|
      UserLookup.lookup_columns << column
      UserLookup.lookup_columns.uniq!
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def add_body_class(class_name)
    reloadable_patch do |plugin|
      ::ApplicationHelper.extra_body_classes << class_name
    end
  end

  def rescue_from(exception, &block)
    reloadable_patch do |plugin|
      ::ApplicationController.rescue_from(exception, &block)
    end
  end

  # Extend a class but check that the plugin is enabled
  # for class methods use `add_class_method`
  def add_to_class(class_name, attr, &block)
    reloadable_patch do |plugin|
      klass = class_name.to_s.classify.constantize rescue class_name.to_s.constantize
      hidden_method_name = :"#{attr}_without_enable_check"
      klass.public_send(:define_method, hidden_method_name, &block)

      klass.public_send(:define_method, attr) do |*args|
        public_send(hidden_method_name, *args) if plugin.enabled?
      end
    end
  end

  # Adds a class method to a class, respecting if plugin is enabled
  def add_class_method(klass_name, attr, &block)
    reloadable_patch do |plugin|
      klass = klass_name.to_s.classify.constantize rescue klass_name.to_s.constantize

      hidden_method_name = :"#{attr}_without_enable_check"
      klass.public_send(:define_singleton_method, hidden_method_name, &block)

      klass.public_send(:define_singleton_method, attr) do |*args|
        public_send(hidden_method_name, *args) if plugin.enabled?
      end
    end
  end

  def add_model_callback(klass_name, callback, options = {}, &block)
    reloadable_patch do |plugin|
      klass = klass_name.to_s.classify.constantize rescue klass_name.to_s.constantize

      # generate a unique method name
      method_name = "#{plugin.name}_#{klass.name}_#{callback}#{@idx}".underscore
      @idx += 1
      hidden_method_name = :"#{method_name}_without_enable_check"
      klass.public_send(:define_method, hidden_method_name, &block)

      klass.public_send(callback, **options) do |*args|
        public_send(hidden_method_name, *args) if plugin.enabled?
      end

      hidden_method_name
    end
  end

  def topic_view_post_custom_fields_whitelister(&block)
    Discourse.deprecate("topic_view_post_custom_fields_whitelister is deprecated, use the topic_view_post_custom_fields_allowlister.", drop_from: "2.6", raise_error: true)
    topic_view_post_custom_fields_allowlister(&block)
  end

  # Add a post_custom_fields_allowlister block to the TopicView, respecting if the plugin is enabled
  def topic_view_post_custom_fields_allowlister(&block)
    reloadable_patch do |plugin|
      ::TopicView.add_post_custom_fields_allowlister do |user, topic|
        plugin.enabled? ? block.call(user, topic) : []
      end
    end
  end

  # Allows to add additional user_ids to the list of people notified when doing a post revision
  def add_post_revision_notifier_recipients(&block)
    reloadable_patch do |plugin|
      ::PostActionNotifier.add_post_revision_notifier_recipients do |post_revision|
        plugin.enabled? ? block.call(post_revision) : []
      end
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def add_preloaded_group_custom_field(field)
    reloadable_patch do |plugin|
      ::Group.preloaded_custom_field_names << field
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def add_preloaded_topic_list_custom_field(field)
    reloadable_patch do |plugin|
      ::TopicList.preloaded_custom_fields << field
    end
  end

  # Add a permitted_create_param to Post, respecting if the plugin is enabled
  def add_permitted_post_create_param(name, type = :string)
    reloadable_patch do |plugin|
      ::Post.plugin_permitted_create_params[name] = { plugin: plugin, type: type }
    end
  end

  # Add a permitted_update_param to Post, respecting if the plugin is enabled
  def add_permitted_post_update_param(attribute, &block)
    reloadable_patch do |plugin|
      ::Post.plugin_permitted_update_params[attribute] = { plugin: plugin, handler: block }
    end
  end

  # Add a permitted_param to Group, respecting if the plugin is enabled
  # Used in GroupsController#update and Admin::GroupsController#create
  def register_group_param(param)
    DiscoursePluginRegistry.register_group_param(param, self)
  end

  # Add a custom callback for search to Group
  # Callback is called in UsersController#search_users
  # Block takes groups and optional current_user
  # For example:
  # plugin.register_groups_callback_for_users_search_controller_action(:admins_filter) do |groups, user|
  #   groups.where(name: "admins")
  # end
  def register_groups_callback_for_users_search_controller_action(callback, &block)
    if DiscoursePluginRegistry.groups_callback_for_users_search_controller_action.key?(callback)
      raise "groups_callback_for_users_search_controller_action callback already registered"
    end

    DiscoursePluginRegistry.groups_callback_for_users_search_controller_action[callback] = block
  end

  # Add validation method but check that the plugin is enabled
  def validate(klass, name, &block)
    klass = klass.to_s.classify.constantize
    klass.public_send(:define_method, name, &block)

    plugin = self
    klass.validate(name, if: -> { plugin.enabled? })
  end

  # will make sure all the assets this plugin needs are registered
  def generate_automatic_assets!
    paths = []
    assets = []

    automatic_assets.each do |path, contents|
      write_asset(path, contents)
      paths << path
      assets << [path, nil, directory_name]
    end

    delete_extra_automatic_assets(paths)

    assets
  end

  def add_directory_column(column_name, query:, icon: nil)
    validate_directory_column_name(column_name)

    DiscourseEvent.on("before_directory_refresh") do
      DirectoryColumn.find_or_create_plugin_directory_column(column_name: column_name, icon: icon, query: query)
    end
  end

  def delete_extra_automatic_assets(good_paths)
    return unless Dir.exist? auto_generated_path

    filenames = good_paths.map { |f| File.basename(f) }
    # nuke old files
    Dir.foreach(auto_generated_path) do |p|
      next if [".", ".."].include?(p)
      next if filenames.include?(p)
      File.delete(auto_generated_path + "/#{p}")
    end
  end

  def ensure_directory(path)
    dirname = File.dirname(path)
    unless File.directory?(dirname)
      FileUtils.mkdir_p(dirname)
    end
  end

  def directory
    File.dirname(path)
  end

  def auto_generated_path
    File.dirname(path) << "/auto_generated"
  end

  def after_initialize(&block)
    initializers << block
  end

  def before_auth(&block)
    raise "Auth providers must be registered before omniauth middleware. after_initialize is too late!" if @before_auth_complete
    before_auth_initializers << block
  end

  # A proxy to `DiscourseEvent.on` which does nothing if the plugin is disabled
  def on(event_name, &block)
    DiscourseEvent.on(event_name) do |*args|
      block.call(*args) if enabled?
    end
  end

  def notify_after_initialize
    color_schemes.each do |c|
      unless ColorScheme.where(name: c[:name]).exists?
        ColorScheme.create_from_base(name: c[:name], colors: c[:colors])
      end
    end

    initializers.each do |callback|
      begin
        callback.call(self)
      rescue ActiveRecord::StatementInvalid => e
        # When running `db:migrate` for the first time on a new database,
        # plugin initializers might try to use models.
        # Tolerate it.
        raise e unless e.message.try(:include?, "PG::UndefinedTable")
      end
    end
  end

  def notify_before_auth
    before_auth_initializers.each do |callback|
      callback.call(self)
    end
    @before_auth_complete = true
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_category_custom_field_type(name, type)
    reloadable_patch do |plugin|
      Category.register_custom_field_type(name, type)
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_topic_custom_field_type(name, type)
    reloadable_patch do |plugin|
      ::Topic.register_custom_field_type(name, type)
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_post_custom_field_type(name, type)
    reloadable_patch do |plugin|
      ::Post.register_custom_field_type(name, type)
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_group_custom_field_type(name, type)
    reloadable_patch do |plugin|
      ::Group.register_custom_field_type(name, type)
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_user_custom_field_type(name, type)
    reloadable_patch do |plugin|
      ::User.register_custom_field_type(name, type)
    end
  end

  def register_seedfu_fixtures(paths)
    paths = [paths] if !paths.kind_of?(Array)
    SeedFu.fixture_paths.concat(paths)
  end

  def register_seedfu_filter(filter = nil)
    DiscoursePluginRegistry.register_seedfu_filter(filter)
  end

  def listen_for(event_name)
    return unless self.respond_to?(event_name)
    DiscourseEvent.on(event_name, &self.method(event_name))
  end

  def register_css(style)
    styles << style
  end

  def register_javascript(js)
    javascripts << js
  end

  def register_svg_icon(icon)
    DiscoursePluginRegistry.register_svg_icon(icon)
  end

  def extend_content_security_policy(extension)
    csp_extensions << extension
  end

  # Register a block to run when adding css and js assets
  # Two arguments will be passed: (type, request)
  # Type is :css or :js. `request` is an instance of Rack::Request
  # When using this, make sure to consider the effect on AnonymousCache
  def register_asset_filter(&blk)
    asset_filters << blk
  end

  # @option opts [String] :name
  # @option opts [String] :nativeName
  # @option opts [String] :fallbackLocale
  # @option opts [Hash] :plural
  def register_locale(locale, opts = {})
    locales << [locale, opts]
  end

  def register_custom_html(hash)
    DiscoursePluginRegistry.custom_html.merge!(hash)
  end

  def register_html_builder(name, &block)
    plugin = self
    DiscoursePluginRegistry.register_html_builder(name) do |*args|
      block.call(*args) if plugin.enabled?
    end
  end

  def register_asset(file, opts = nil)
    if opts && opts == :vendored_core_pretty_text
      full_path = DiscoursePluginRegistry.core_asset_for_name(file)
    else
      full_path = File.dirname(path) << "/assets/" << file
    end

    assets << [full_path, opts, directory_name]
  end

  def register_service_worker(file, opts = nil)
    service_workers << [
      File.join(File.dirname(path), 'assets', file),
      opts
    ]
  end

  def register_color_scheme(name, colors)
    color_schemes << { name: name, colors: colors }
  end

  def register_seed_data(key, value)
    seed_data[key] = value
  end

  def register_seed_path_builder(&block)
    DiscoursePluginRegistry.register_seed_path_builder(&block)
  end

  def register_emoji(name, url, group = Emoji::DEFAULT_GROUP)
    Plugin::CustomEmoji.register(name, url, group)
    Emoji.clear_cache
  end

  def translate_emoji(from, to)
    Plugin::CustomEmoji.translate(from, to)
  end

  def automatic_assets
    css = styles.join("\n")
    js = javascripts.join("\n")

    # Generate an IIFE for the JS
    js = "(function(){#{js}})();" if js.present?

    result = []
    result << [css, 'css'] if css.present?
    result << [js, 'js'] if js.present?

    result.map do |asset, extension|
      hash = Digest::SHA1.hexdigest asset
      ["#{auto_generated_path}/plugin_#{hash}.#{extension}", asset]
    end
  end

  # note, we need to be able to parse separately to activation.
  # this allows us to present information about a plugin in the UI
  # prior to activations
  def activate!
    if @path
      root_dir_name = File.dirname(@path)

      # Automatically include all ES6 JS and hbs files
      root_path = "#{root_dir_name}/assets/javascripts"
      DiscoursePluginRegistry.register_glob(root_path, 'js') if transpile_js
      DiscoursePluginRegistry.register_glob(root_path, 'js.es6')
      DiscoursePluginRegistry.register_glob(root_path, 'hbs')
      DiscoursePluginRegistry.register_glob(root_path, 'hbr')

      admin_path = "#{root_dir_name}/admin/assets/javascripts"
      DiscoursePluginRegistry.register_glob(admin_path, 'js', admin: true) if transpile_js
      DiscoursePluginRegistry.register_glob(admin_path, 'js.es6', admin: true)
      DiscoursePluginRegistry.register_glob(admin_path, 'hbs', admin: true)
      DiscoursePluginRegistry.register_glob(admin_path, 'hbr', admin: true)

      if transpile_js
        DiscourseJsProcessor.plugin_transpile_paths << root_path.sub(Rails.root.to_s, '').sub(/^\/*/, '')
        DiscourseJsProcessor.plugin_transpile_paths << admin_path.sub(Rails.root.to_s, '').sub(/^\/*/, '')

        test_path = "#{root_dir_name}/test/javascripts"
        DiscourseJsProcessor.plugin_transpile_paths << test_path.sub(Rails.root.to_s, '').sub(/^\/*/, '')
      end
    end

    self.instance_eval File.read(path), path
    if auto_assets = generate_automatic_assets!
      assets.concat(auto_assets)
    end

    register_assets! unless assets.blank?
    register_locales!
    register_service_workers!

    seed_data.each do |key, value|
      DiscoursePluginRegistry.register_seed_data(key, value)
    end

    # TODO: possibly amend this to a rails engine

    # Automatically include assets
    Rails.configuration.assets.paths << auto_generated_path
    Rails.configuration.assets.paths << File.dirname(path) + "/assets"
    Rails.configuration.assets.paths << File.dirname(path) + "/admin/assets"
    Rails.configuration.assets.paths << File.dirname(path) + "/test/javascripts"

    # Automatically include rake tasks
    Rake.add_rakelib(File.dirname(path) + "/lib/tasks")

    # Automatically include migrations
    migration_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths
    migration_paths << File.dirname(path) + "/db/migrate"

    unless Discourse.skip_post_deployment_migrations?
      migration_paths << "#{File.dirname(path)}/#{Discourse::DB_POST_MIGRATE_PATH}"
    end

    public_data = File.dirname(path) + "/public"
    if Dir.exist?(public_data)
      target = Rails.root.to_s + "/public/plugins/"

      Discourse::Utils.execute_command('mkdir', '-p', target)
      target << name.gsub(/\s/, "_")

      Discourse::Utils.atomic_ln_s(public_data, target)
    end

    ensure_directory(js_file_path)

    contents = []
    handlebars_includes.each { |hb| contents << "require_asset('#{hb}')" }
    javascript_includes.each { |js| contents << "require_asset('#{js}')" }

    each_globbed_asset do |f, is_dir|
      contents << (is_dir ? "depend_on('#{f}')" : "require_asset('#{f}')")
    end

    if contents.present?
      contents.insert(0, "<%")
      contents << "%>"
      Discourse::Utils.atomic_write_file(js_file_path, contents.join("\n"))
    else
      begin
        File.delete(js_file_path)
      rescue Errno::ENOENT
      end
    end
  end

  def auth_provider(opts)
    before_auth do
      provider = Auth::AuthProvider.new

      Auth::AuthProvider.auth_attributes.each do |sym|
        provider.public_send("#{sym}=", opts.delete(sym)) if opts.has_key?(sym)
      end

      begin
        provider.authenticator.enabled?
      rescue NotImplementedError
        provider.authenticator.define_singleton_method(:enabled?) do
          Discourse.deprecate("#{provider.authenticator.class.name} should define an `enabled?` function. Patching for now.", drop_from: '2.9.0')
          return SiteSetting.get(provider.enabled_setting) if provider.enabled_setting
          Discourse.deprecate("#{provider.authenticator.class.name} has not defined an enabled_setting. Defaulting to true.", drop_from: '2.9.0')
          true
        end
      end

      DiscoursePluginRegistry.register_auth_provider(provider)
    end
  end

  # shotgun approach to gem loading, in future we need to hack bundler
  #  to at least determine dependencies do not clash before loading
  #
  # Additionally we want to support multiple ruby versions correctly and so on
  #
  # This is a very rough initial implementation
  def gem(name, version, opts = {})
    PluginGem.load(path, name, version, opts)
  end

  def hide_plugin
    Discourse.hidden_plugins << self
  end

  def enabled_site_setting_filter(filter = nil)
    STDERR.puts("`enabled_site_setting_filter` is deprecated")
  end

  def enabled_site_setting(setting = nil)
    if setting
      @enabled_site_setting = setting
    else
      @enabled_site_setting
    end
  end

  def handlebars_includes
    assets.map do |asset, opts|
      next if opts == :admin
      next unless asset =~ DiscoursePluginRegistry::HANDLEBARS_REGEX
      asset
    end.compact
  end

  def javascript_includes
    assets.map do |asset, opts|
      next if opts == :vendored_core_pretty_text
      next if opts == :admin
      next unless asset =~ DiscoursePluginRegistry::JS_REGEX
      asset
    end.compact
  end

  def each_globbed_asset
    if @path
      # Automatically include all ES6 JS and hbs files
      root_path = "#{File.dirname(@path)}/assets/javascripts"
      admin_path = "#{File.dirname(@path)}/admin/assets/javascripts"

      Dir.glob(["#{root_path}/**/*", "#{admin_path}/**/*"]).sort.each do |f|
        f_str = f.to_s
        if File.directory?(f)
          yield [f, true]
        elsif f_str.end_with?(".js.es6") || f_str.end_with?(".hbs") || f_str.end_with?(".hbr")
          yield [f, false]
        elsif transpile_js && f_str.end_with?(".js")
          yield [f, false]
        end
      end
    end
  end

  def register_reviewable_type(reviewable_type_class)
    extend_list_method Reviewable, :types, [reviewable_type_class.name]
  end

  def extend_list_method(klass, method, new_attributes)
    current_list = klass.public_send(method)
    current_list.concat(new_attributes)

    reloadable_patch do
      klass.public_send(:define_singleton_method, method) { current_list }
    end
  end

  def directory_name
    @directory_name ||= File.dirname(path).split("/").last
  end

  def css_asset_exists?(target = nil)
    DiscoursePluginRegistry.stylesheets_exists?(directory_name, target)
  end

  def js_asset_exists?
    File.exist?(js_file_path)
  end

  # Receives an array with two elements:
  # 1. A symbol that represents the name of the value to filter.
  # 2. A Proc that takes the existing ActiveRecord::Relation and the value received from the front-end.
  def add_custom_reviewable_filter(filter)
    reloadable_patch do
      Reviewable.add_custom_filter(filter)
    end
  end

  # Register a new API key scope.
  #
  # Example:
  # add_api_key_scope(:groups, { delete: { actions: %w[groups#add_members], params: %i[id] } })
  #
  # This scope lets you add members to a group. Additionally, you can specify which group ids are allowed.
  # The delete action is added to the groups resource.
  def add_api_key_scope(resource, action)
    DiscoursePluginRegistry.register_api_key_scope_mapping({ resource => action }, self)
  end

  # Register a new UserApiKey scope, and its allowed routes. Scope will be prefixed
  # with the (parameterized) plugin name followed by a colon.
  #
  # For example, if discourse-awesome-plugin registered this:
  #
  # add_user_api_key_scope(:read_my_route,
  #   methods: :get,
  #   actions: "mycontroller#myaction",
  #   formats: :ics,
  #   params: :testparam
  # )
  #
  # The scope registered would be `discourse-awesome-plugin:read_my_route`
  #
  # Multiple matchers can be attached by supplying an array of parameter hashes
  #
  # See UserApiKeyScope::SCOPES for more examples
  # And lib/route_matcher.rb for the route matching logic
  def add_user_api_key_scope(scope_name, matcher_parameters)
    raise ArgumentError.new("scope_name must be a symbol") if !scope_name.is_a?(Symbol)
    matcher_parameters = [matcher_parameters] if !matcher_parameters.is_a?(Array)

    prefixed_scope_name = :"#{(name || directory_name).parameterize}:#{scope_name}"
    DiscoursePluginRegistry.register_user_api_key_scope_mapping(
      {
        prefixed_scope_name => matcher_parameters&.map { |m| RouteMatcher.new(**m) }
      }, self)
  end

  # Register a route which can be authenticated using an api key or user api key
  # in a query parameter rather than a header. For example:
  #
  # add_api_parameter_route(
  #   methods: :get,
  #   actions: "users#bookmarks",
  #   formats: :ics
  # )
  #
  # See Auth::DefaultCurrentUserProvider::PARAMETER_API_PATTERNS for more examples
  # and Auth::DefaultCurrentUserProvider#api_parameter_allowed? for implementation
  def add_api_parameter_route(method: nil, methods: nil,
                              route: nil, actions: nil,
                              format: nil, formats: nil)

    if Array(format).include?("*")
      Discourse.deprecate("* is no longer a valid api_parameter_route format matcher. Use `nil` instead", drop_from: "2.7", raise_error: true)
      # Old API used * as wildcard. New api uses `nil`
      format = nil
    end

    # Backwards compatibility with old parameter names:
    if method || route || format
      Discourse.deprecate("method, route and format parameters for api_parameter_routes are deprecated. Use methods, actions and formats instead.", drop_from: "2.7", raise_error: true)
      methods ||= method
      actions ||= route
      formats ||= format
    end

    DiscoursePluginRegistry.register_api_parameter_route(
      RouteMatcher.new(
        methods: methods,
        actions: actions,
        formats: formats
      ), self)
  end

  # Register a new demon process to be forked by the Unicorn master.
  # The demon_class should inherit from Demon::Base.
  # With great power comes great responsibility - this method should
  # be used with extreme caution. See `config/unicorn.conf.rb`.
  def register_demon_process(demon_class)
    raise "Not a demon class" if !demon_class.ancestors.include?(Demon::Base)
    DiscoursePluginRegistry.demon_processes << demon_class
  end

  def add_permitted_reviewable_param(type, param)
    DiscoursePluginRegistry.register_reviewable_param({
      type: type,
      param: param
      }, self)
  end

  # Register a new PresenceChannel prefix. See {PresenceChannel.register_prefix}
  # for usage instructions
  def register_presence_channel_prefix(prefix, &block)
    DiscoursePluginRegistry.register_presence_channel_prefix([prefix, block], self)
  end

  # Registers a new push notification filter. User and notification payload are passed into block, and if all
  # filters return `true`, the push notification will be sent.
  def register_push_notification_filter(&block)
    DiscoursePluginRegistry.register_push_notification_filter(block, self)
  end

  # Register a ReviewableScore setting_name associated with a reason.
  # We'll use this to build a site setting link and add it to the reason's translation.
  #
  # If your plugin has a reason translation looking like this:
  #
  #   my_plugin_reason: "This is the reason this post was flagged. See %{link}."
  #
  # And you associate the reason with a setting:
  #
  #   add_reviewable_score_link(:my_plugin_reason, 'a_plugin_setting')
  #
  # We'll generate the following link and attach it to the translation:
  #
  #   <a href="/admin/site_settings/category/all_results?filter=a_plugin_setting">
  #     a plugin setting
  #   </a>
  def add_reviewable_score_link(reason, setting_name)
    DiscoursePluginRegistry.register_reviewable_score_link({ reason: reason.to_sym, setting: setting_name }, self)
  end

  # If your plugin creates notifications, and you'd like to consolidate/collapse similar ones,
  # you're in the right place.
  # This method receives a plan object, which must be an instance of `Notifications::ConsolidateNotifications`.
  #
  # Instead of using `Notification#create!`, you should use `Notification#consolidate_or_save!`,
  # which will automatically pick your plan and apply it, updating an already consolidated notification,
  # consolidating multiple ones, or creating a regular one.
  #
  # The rule object is quite complex. We strongly recommend you write tests to ensure your plugin consolidates notifications correctly.
  #
  # - Threshold and time window consolidation plan: https://github.com/discourse/discourse/blob/main/app/services/notifications/consolidate_notifications.rb
  # - Create a new notification and delete previous versions plan: https://github.com/discourse/discourse/blob/main/app/services/notifications/delete_previous_notifications.rb
  # - Base plans: https://github.com/discourse/discourse/blob/main/app/services/notifications/consolidation_planner.rb
  def register_notification_consolidation_plan(plan)
    raise ArgumentError.new("Not a consolidation plan") if !plan.class.ancestors.include?(Notifications::ConsolidationPlan)
    DiscoursePluginRegistry.register_notification_consolidation_plan(plan, self)
  end

  # Allows customizing existing topic-backed static pages, like:
  # faq, tos, privacy (see: StaticController) The block passed to this
  # method has to return a SiteSetting name that contains a topic id.
  #
  #   add_topic_static_page("faq") do |controller|
  #     current_user&.locale == "pl" ? "polish_faq_topic_id" : "faq_topic_id"
  #   end
  #
  # You can also add new pages in a plugin, but remember to add a route,
  # for example:
  #
  #   get "contact" => "static#show", id: "contact"
  def add_topic_static_page(page, options = {}, &blk)
    StaticController::CUSTOM_PAGES[page] = blk ? { topic_id: blk } : options
  end

  protected

  def self.js_path
    File.expand_path "#{Rails.root}/app/assets/javascripts/plugins"
  end

  def js_file_path
    @file_path ||= "#{Plugin::Instance.js_path}/#{directory_name}.js.erb"
  end

  def register_assets!
    assets.each do |asset, opts, plugin_directory_name|
      DiscoursePluginRegistry.register_asset(asset, opts, plugin_directory_name)
    end
  end

  def register_service_workers!
    service_workers.each do |asset, opts|
      DiscoursePluginRegistry.register_service_worker(asset, opts)
    end
  end

  def register_locales!
    root_path = File.dirname(@path)

    locales.each do |locale, opts|
      opts = opts.dup
      opts[:client_locale_file] = Dir["#{root_path}/config/locales/client*.#{locale}.yml"].first || ""
      opts[:server_locale_file] = Dir["#{root_path}/config/locales/server*.#{locale}.yml"].first || ""
      opts[:js_locale_file] = File.join(root_path, "assets/locales/#{locale}.js.erb")

      locale_chain = opts[:fallbackLocale] ? [locale, opts[:fallbackLocale]] : [locale]
      lib_locale_path = File.join(root_path, "lib/javascripts/locale")

      path = File.join(lib_locale_path, "message_format")
      opts[:message_format] = find_locale_file(locale_chain, path)
      opts[:message_format] = JsLocaleHelper.find_message_format_locale(locale_chain, fallback_to_english: false) unless opts[:message_format]

      path = File.join(lib_locale_path, "moment_js")
      opts[:moment_js] = find_locale_file(locale_chain, path)
      opts[:moment_js] = JsLocaleHelper.find_moment_locale(locale_chain) unless opts[:moment_js]

      path = File.join(lib_locale_path, "moment_js_timezones")
      opts[:moment_js_timezones] = find_locale_file(locale_chain, path)
      opts[:moment_js_timezones] = JsLocaleHelper.find_moment_locale(locale_chain, timezone_names: true) unless opts[:moment_js_timezones]

      if valid_locale?(opts)
        DiscoursePluginRegistry.register_locale(locale, opts)
        Rails.configuration.assets.precompile << "locales/#{locale}.js"
      else
        msg = "Invalid locale! #{opts.inspect}"
        # The logger isn't always present during boot / parsing locales from plugins
        if Rails.logger.present?
          Rails.logger.error(msg)
        else
          puts msg
        end
      end
    end
  end

  def allow_new_queued_post_payload_attribute(attribute_name)
    reloadable_patch do
      NewPostManager.add_plugin_payload_attribute(attribute_name)
    end
  end

  private

  def validate_directory_column_name(column_name)
    match = /^[_a-z]+$/.match(column_name)
    raise "Invalid directory column name '#{column_name}'. Can only contain a-z and underscores" unless match
  end

  def write_asset(path, contents)
    unless File.exist?(path)
      ensure_directory(path)
      File.open(path, "w") { |f| f.write(contents) }
    end
  end

  def reloadable_patch(plugin = self)
    if Rails.env.development? && defined?(ActiveSupport::Reloader)
      ActiveSupport::Reloader.to_prepare do
        # reload the patch
        yield plugin
      end
    end

    # apply the patch
    yield plugin
  end

  def valid_locale?(custom_locale)
    File.exist?(custom_locale[:client_locale_file]) &&
      File.exist?(custom_locale[:server_locale_file]) &&
      File.exist?(custom_locale[:js_locale_file]) &&
      custom_locale[:message_format] && custom_locale[:moment_js]
  end

  def find_locale_file(locale_chain, path)
    locale_chain.each do |locale|
      filename = File.join(path, "#{locale}.js")
      return [locale, filename] if File.exist?(filename)
    end
    nil
  end

  def register_permitted_bulk_action_parameter(name)
    DiscoursePluginRegistry.register_permitted_bulk_action_parameter(name, self)
  end
end
