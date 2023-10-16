# frozen_string_literal: true

require "digest/sha1"
require "fileutils"
require "plugin/metadata"
require "auth"

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
  %i[
    assets
    color_schemes
    before_auth_initializers
    initializers
    javascripts
    locales
    service_workers
    styles
    themes
    csp_extensions
    asset_filters
  ].each do |att|
    class_eval %Q{
      def #{att}
        @#{att} ||= []
      end
    }
  end

  def seed_data
    @seed_data ||= HashWithIndifferentAccess.new({})
  end

  def seed_fu_filter(filter = nil)
    @seed_fu_filter = filter
  end

  def self.find_all(parent_path)
    [].tap do |plugins|
      # also follows symlinks - http://stackoverflow.com/q/357754
      Dir["#{parent_path}/*/plugin.rb"].sort.each do |path|
        source = File.read(path)
        metadata = Plugin::Metadata.parse(source)
        plugins << self.new(metadata, path)
      end
    end
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

  def configurable?
    true
  end

  def visible?
    configurable? && !@hidden
  end

  def enabled?
    return false if !configurable?
    @enabled_site_setting ? SiteSetting.get(@enabled_site_setting) : true
  end

  delegate :name, to: :metadata

  def add_to_serializer(
    serializer,
    attr,
    deprecated_respect_plugin_enabled = nil,
    respect_plugin_enabled: true,
    include_condition: nil,
    &block
  )
    if !deprecated_respect_plugin_enabled.nil?
      Discourse.deprecate(
        "add_to_serializer's respect_plugin_enabled argument should be passed as a keyword argument",
      )
      respect_plugin_enabled = deprecated_respect_plugin_enabled
    end

    if attr.to_s.starts_with?("include_")
      Discourse.deprecate(
        "add_to_serializer should not be used to directly override include_*? methods. Use the include_condition keyword argument instead",
      )
    end

    reloadable_patch do |plugin|
      base =
        begin
          "#{serializer.to_s.classify}Serializer".constantize
        rescue StandardError
          "#{serializer.to_s}Serializer".constantize
        end

      # we have to work through descendants cause serializers may already be baked and cached
      ([base] + base.descendants).each do |klass|
        unless attr.to_s.start_with?("include_")
          klass.attributes(attr)

          if respect_plugin_enabled || include_condition
            # Don't include serialized methods if the plugin is disabled
            klass.public_send(:define_method, "include_#{attr}?") do
              next false if respect_plugin_enabled && !plugin.enabled?
              next instance_exec(&include_condition) if include_condition
              true
            end
          end
        end

        klass.public_send(:define_method, attr, &block)
      end
    end
  end

  def register_modifier(modifier_name, &blk)
    DiscoursePluginRegistry.register_modifier(self, modifier_name, &blk)
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def add_report(name, &block)
    reloadable_patch { |plugin| Report.add_report(name, &block) }
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

  def allow_staff_user_custom_field(field)
    DiscoursePluginRegistry.register_staff_user_custom_field(field, self)
  end

  def allow_public_user_custom_field(field)
    DiscoursePluginRegistry.register_public_user_custom_field(field, self)
  end

  def register_editable_topic_custom_field(field, staff_only: false)
    if staff_only
      DiscoursePluginRegistry.register_staff_editable_topic_custom_field(field, self)
    else
      DiscoursePluginRegistry.register_public_editable_topic_custom_field(field, self)
    end
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

  def register_upload_unused(&block)
    Upload.add_unused_callback(&block)
  end

  def register_upload_in_use(&block)
    Upload.add_in_use_callback(&block)
  end

  def custom_avatar_column(column)
    reloadable_patch do |plugin|
      UserLookup.lookup_columns << column
      UserLookup.lookup_columns.uniq!
    end
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def add_body_class(class_name)
    reloadable_patch { |plugin| ::ApplicationHelper.extra_body_classes << class_name }
  end

  def rescue_from(exception, &block)
    reloadable_patch { |plugin| ::ApplicationController.rescue_from(exception, &block) }
  end

  # Extend a class but check that the plugin is enabled
  # for class methods use `add_class_method`
  def add_to_class(class_name, attr, &block)
    reloadable_patch do |plugin|
      klass =
        begin
          class_name.to_s.classify.constantize
        rescue StandardError
          class_name.to_s.constantize
        end
      hidden_method_name = :"#{attr}_without_enable_check"
      klass.public_send(:define_method, hidden_method_name, &block)

      klass.public_send(:define_method, attr) do |*args, **kwargs|
        public_send(hidden_method_name, *args, **kwargs) if plugin.enabled?
      end
    end
  end

  # Adds a class method to a class, respecting if plugin is enabled
  def add_class_method(klass_name, attr, &block)
    reloadable_patch do |plugin|
      klass =
        begin
          klass_name.to_s.classify.constantize
        rescue StandardError
          klass_name.to_s.constantize
        end

      hidden_method_name = :"#{attr}_without_enable_check"
      klass.public_send(:define_singleton_method, hidden_method_name, &block)

      klass.public_send(:define_singleton_method, attr) do |*args, **kwargs|
        public_send(hidden_method_name, *args, **kwargs) if plugin.enabled?
      end
    end
  end

  def add_model_callback(klass_name, callback, options = {}, &block)
    reloadable_patch do |plugin|
      klass =
        begin
          klass_name.to_s.classify.constantize
        rescue StandardError
          klass_name.to_s.constantize
        end

      # generate a unique method name
      method_name = "#{plugin.name}_#{klass.name}_#{callback}#{@idx}".underscore
      @idx += 1
      hidden_method_name = :"#{method_name}_without_enable_check"
      klass.public_send(:define_method, hidden_method_name, &block)

      klass.public_send(callback, **options) do |*args, **kwargs|
        public_send(hidden_method_name, *args, **kwargs) if plugin.enabled?
      end

      hidden_method_name
    end
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
    reloadable_patch { |plugin| ::Group.preloaded_custom_field_names << field }
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def add_preloaded_topic_list_custom_field(field)
    reloadable_patch { |plugin| ::TopicList.preloaded_custom_fields << field }
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
      DirectoryColumn.find_or_create_plugin_directory_column(
        column_name: column_name,
        icon: icon,
        query: query,
      )
    end
  end

  def delete_extra_automatic_assets(good_paths)
    return unless Dir.exist? auto_generated_path

    filenames = good_paths.map { |f| File.basename(f) }
    # nuke old files
    Dir.foreach(auto_generated_path) do |p|
      next if %w[. ..].include?(p)
      next if filenames.include?(p)
      File.delete(auto_generated_path + "/#{p}")
    end
  end

  def ensure_directory(path)
    dirname = File.dirname(path)
    FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
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

  def commit_hash
    git_repo.latest_local_commit
  end

  def commit_url
    return if commit_hash.blank?
    "#{git_repo.url}/commit/#{commit_hash}"
  end

  def git_repo
    @git_repo ||= GitRepo.new(directory, name)
  end

  def before_auth(&block)
    if @before_auth_complete
      raise "Auth providers must be registered before omniauth middleware. after_initialize is too late!"
    end
    before_auth_initializers << block
  end

  # A proxy to `DiscourseEvent.on` which does nothing if the plugin is disabled
  def on(event_name, &block)
    DiscourseEvent.on(event_name) { |*args, **kwargs| block.call(*args, **kwargs) if enabled? }
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
    before_auth_initializers.each { |callback| callback.call(self) }
    @before_auth_complete = true
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_category_custom_field_type(name, type)
    reloadable_patch { |plugin| Category.register_custom_field_type(name, type) }
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_topic_custom_field_type(name, type)
    reloadable_patch { |plugin| ::Topic.register_custom_field_type(name, type) }
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_post_custom_field_type(name, type)
    reloadable_patch { |plugin| ::Post.register_custom_field_type(name, type) }
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_group_custom_field_type(name, type)
    reloadable_patch { |plugin| ::Group.register_custom_field_type(name, type) }
  end

  # Applies to all sites in a multisite environment. Ignores plugin.enabled?
  def register_user_custom_field_type(name, type)
    reloadable_patch { |plugin| ::User.register_custom_field_type(name, type) }
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
    DiscoursePluginRegistry.register_html_builder(name) do |*args, **kwargs|
      block.call(*args, **kwargs) if plugin.enabled?
    end
  end

  def register_email_poller(poller)
    plugin = self
    DiscoursePluginRegistry.register_mail_poller(poller) if plugin.enabled?
  end

  def register_asset(file, opts = nil)
    raise <<~ERROR if file.end_with?(".hbs", ".handlebars")
        [#{name}] Handlebars templates can no longer be included via `register_asset`.
        Any hbs files under `assets/javascripts` will be automatically compiled and included."
      ERROR

    if opts && opts == :vendored_core_pretty_text
      full_path = DiscoursePluginRegistry.core_asset_for_name(file)
    else
      full_path = File.dirname(path) << "/assets/" << file
    end

    assets << [full_path, opts, directory_name]
  end

  def register_service_worker(file, opts = nil)
    service_workers << [File.join(File.dirname(path), "assets", file), opts]
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
    name = name.gsub(/[^a-z0-9]+/i, "_").gsub(/_{2,}/, "_").downcase
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
    result << [css, "css"] if css.present?
    result << [js, "js"] if js.present?

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
      DiscoursePluginRegistry.register_glob(root_path, "js")
      DiscoursePluginRegistry.register_glob(root_path, "js.es6")
      DiscoursePluginRegistry.register_glob(root_path, "hbs")
      DiscoursePluginRegistry.register_glob(root_path, "hbr")

      admin_path = "#{root_dir_name}/admin/assets/javascripts"
      DiscoursePluginRegistry.register_glob(admin_path, "js", admin: true)
      DiscoursePluginRegistry.register_glob(admin_path, "js.es6", admin: true)
      DiscoursePluginRegistry.register_glob(admin_path, "hbs", admin: true)
      DiscoursePluginRegistry.register_glob(admin_path, "hbr", admin: true)

      DiscourseJsProcessor.plugin_transpile_paths << root_path.sub(Rails.root.to_s, "").sub(
        %r{\A/*},
        "",
      )
      DiscourseJsProcessor.plugin_transpile_paths << admin_path.sub(Rails.root.to_s, "").sub(
        %r{\A/*},
        "",
      )

      test_path = "#{root_dir_name}/test/javascripts"
      DiscourseJsProcessor.plugin_transpile_paths << test_path.sub(Rails.root.to_s, "").sub(
        %r{\A/*},
        "",
      )
    end

    self.instance_eval File.read(path), path
    if auto_assets = generate_automatic_assets!
      assets.concat(auto_assets)
    end

    register_assets! unless assets.blank?
    register_locales!
    register_service_workers!

    seed_data.each { |key, value| DiscoursePluginRegistry.register_seed_data(key, value) }

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

      Discourse::Utils.execute_command("mkdir", "-p", target)
      target << name.gsub(/\s/, "_")

      Discourse::Utils.atomic_ln_s(public_data, target)
    end

    ensure_directory(js_file_path)

    contents = []
    handlebars_includes.each { |hb| contents << "require_asset('#{hb}')" }
    javascript_includes.each { |js| contents << "require_asset('#{js}')" }

    if !contents.present?
      [js_file_path, extra_js_file_path].each do |f|
        File.delete(f)
      rescue Errno::ENOENT
      end
      return
    end

    contents.insert(0, "<%")
    contents << "%>"

    Discourse::Utils.atomic_write_file(extra_js_file_path, contents.join("\n"))

    begin
      File.delete(js_file_path)
    rescue Errno::ENOENT
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
        provider
          .authenticator
          .define_singleton_method(:enabled?) do
            Discourse.deprecate(
              "#{provider.authenticator.class.name} should define an `enabled?` function. Patching for now.",
              drop_from: "2.9.0",
            )
            return SiteSetting.get(provider.enabled_setting) if provider.enabled_setting
            Discourse.deprecate(
              "#{provider.authenticator.class.name} has not defined an enabled_setting. Defaulting to true.",
              drop_from: "2.9.0",
            )
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
    @hidden = true
  end

  def enabled_site_setting(setting = nil)
    if setting
      @enabled_site_setting = setting
    else
      @enabled_site_setting
    end
  end

  def handlebars_includes
    assets
      .map do |asset, opts|
        next if opts == :admin
        next unless asset =~ DiscoursePluginRegistry::HANDLEBARS_REGEX
        asset
      end
      .compact
  end

  def javascript_includes
    assets
      .map do |asset, opts|
        next if opts == :vendored_core_pretty_text
        next if opts == :admin
        next unless asset =~ DiscoursePluginRegistry::JS_REGEX
        asset
      end
      .compact
  end

  def each_globbed_asset
    if @path
      # Automatically include all ES6 JS and hbs files
      root_path = "#{File.dirname(@path)}/assets/javascripts"
      admin_path = "#{File.dirname(@path)}/admin/assets/javascripts"

      Dir
        .glob(["#{root_path}/**/*", "#{admin_path}/**/*"])
        .sort
        .each do |f|
          f_str = f.to_s
          if File.directory?(f)
            yield [f, true]
          elsif f_str.end_with?(".js.es6") || f_str.end_with?(".hbs") || f_str.end_with?(".hbr")
            yield [f, false]
          elsif f_str.end_with?(".js")
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

    reloadable_patch { klass.public_send(:define_singleton_method, method) { current_list } }
  end

  def directory_name
    @directory_name ||= File.dirname(path).split("/").last
  end

  def css_asset_exists?(target = nil)
    DiscoursePluginRegistry.stylesheets_exists?(directory_name, target)
  end

  def js_asset_exists?
    # If assets/javascripts exists, ember-cli will output a .js file
    File.exist?("#{File.dirname(@path)}/assets/javascripts")
  end

  def extra_js_asset_exists?
    File.exist?(extra_js_file_path)
  end

  def admin_js_asset_exists?
    # If this directory exists, ember-cli will output a .js file
    File.exist?("#{File.dirname(@path)}/admin/assets/javascripts")
  end

  # Receives an array with two elements:
  # 1. A symbol that represents the name of the value to filter.
  # 2. A Proc that takes the existing ActiveRecord::Relation and the value received from the front-end.
  def add_custom_reviewable_filter(filter)
    reloadable_patch { Reviewable.add_custom_filter(filter) }
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
      { prefixed_scope_name => matcher_parameters&.map { |m| RouteMatcher.new(**m) } },
      self,
    )
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
  def add_api_parameter_route(methods: nil, actions: nil, formats: nil)
    DiscoursePluginRegistry.register_api_parameter_route(
      RouteMatcher.new(methods: methods, actions: actions, formats: formats),
      self,
    )
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
    DiscoursePluginRegistry.register_reviewable_param({ type: type, param: param }, self)
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
    DiscoursePluginRegistry.register_reviewable_score_link(
      { reason: reason.to_sym, setting: setting_name },
      self,
    )
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
    if !plan.class.ancestors.include?(Notifications::ConsolidationPlan)
      raise ArgumentError.new("Not a consolidation plan")
    end
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

  # Let plugin define custom unsubscribe keys,
  # set custom instance variables on the `EmailController#unsubscribe` action,
  # and describe what unsubscribing for that key does.
  #
  # The method receives a class that inherits from `Email::BaseEmailUnsubscriber`.
  # Take a look at it to know how to implement your child class.
  #
  # In conjunction with this, you'll have to:
  #
  #  - Register a new connector under app/views/connectors/unsubscribe_options.
  #  We'll include the HTML inside the unsubscribe form, so you can add your fields using the
  #  instance variables you set in the controller previously. When the form is submitted,
  #  it sends the updated preferences to `EmailController#perform_unsubscribe`.
  #
  #  - Your code is responsible for creating the custom key by calling `UnsubscribeKey#create_key_for`.
  def register_email_unsubscriber(type, unsubscriber)
    core_types = [UnsubscribeKey::ALL_TYPE, UnsubscribeKey::DIGEST_TYPE, UnsubscribeKey::TOPIC_TYPE]
    raise ArgumentError.new("Type already exists") if core_types.include?(type)
    if !unsubscriber.ancestors.include?(EmailControllerHelper::BaseEmailUnsubscriber)
      raise ArgumentError.new("Not an email unsubscriber")
    end

    DiscoursePluginRegistry.register_email_unsubscriber({ type => unsubscriber }, self)
  end

  # Allows the plugin to export additional site stats via the About class
  # which will be shown on the /about route. The stats returned by the block
  # should be in the following format (these four keys are _required_):
  #
  # {
  #   last_day: 1,
  #   7_days: 10,
  #   30_days: 100,
  #   count: 1000
  # }
  #
  # Only keys above will be shown on the /about page in the UI,
  # but all stats will be shown on the /about.json route. For example take
  # this usage:
  #
  # register_about_stat_group("chat_messages") do
  #   { last_day: 1, "7_days" => 10, "30_days" => 100, count: 1000, previous_30_days: 150 }
  # end
  #
  # In the UI we will show a table like this:
  #
  #               | 24h | 7 days | 30 days | all time|
  # Chat Messages | 1   | 10     | 100     | 1000    |
  #
  # But the JSON will be like this:
  #
  # {
  #   "chat_messages_last_day": 1,
  #   "chat_messages_7_days": 10,
  #   "chat_messages_30_days": 100,
  #   "chat_messages_count": 1000,
  # }
  #
  # The show_in_ui option (default false) is used to determine whether the
  # group of stats is shown on the site About page in the Site Statistics
  # table. Some stats may be needed purely for reporting purposes and thus
  # do not need to be shown in the UI to admins/users.
  def register_about_stat_group(plugin_stat_group_name, show_in_ui: false, &block)
    # We do not want to register and display the same group multiple times.
    if DiscoursePluginRegistry.about_stat_groups.any? { |stat_group|
         stat_group[:name] == plugin_stat_group_name
       }
      return
    end

    DiscoursePluginRegistry.register_about_stat_group(
      { name: plugin_stat_group_name, show_in_ui: show_in_ui, block: block },
      self,
    )
  end

  ##
  # Used to register data sources for HashtagAutocompleteService to look
  # up results based on a #hashtag string.
  #
  # @param {Class} klass - Must be a class that implements methods with the following
  # signatures:
  #
  #   Roughly corresponding to a model, this is used as a unique
  #   key for the datasource and is also used when allowing different
  #   contexts to search for and lookup these types. The `category`
  #   and `tag` types are registered by default.
  #   def self.type
  #   end
  #
  #   The FontAwesome icon to use for the data source in the search results
  #   and cooked markdown.
  #   def self.icon
  #   end
  #
  #   @param {Guardian} guardian - Current user's guardian, used for permission-based filtering
  #   @param {Array} slugs - An array of strings that represent slugs to search this type for,
  #                          e.g. category slugs.
  #   @returns {Hash} A hash with the slug as the key and the URL of the record as the value.
  #   def self.lookup(guardian, slugs)
  #   end
  #
  #   @param {Guardian} guardian - Current user's guardian, used for permission-based filtering
  #   @param {String} term - The search term used to filter results
  #   @param {Integer} limit - The number of search results that should be returned by the query
  #   @returns {Array} An Array of HashtagAutocompleteService::HashtagItem
  #   def self.search(guardian, term, limit)
  #   end
  #
  #   @param {Array} search_results - An array of HashtagAutocompleteService::HashtagItem to sort
  #   @param {String} term - The search term which was used, which may help with sorting.
  #   @returns {Array} An Array of HashtagAutocompleteService::HashtagItem
  #   def self.search_sort(search_results, term)
  #   end
  #
  #   @param {Guardian} guardian - Current user's guardian, used for permission-based filtering
  #   @param {Integer} limit - The number of search results that should be returned by the query
  #   @returns {Array} An Array of HashtagAutocompleteService::HashtagItem
  #   def self.search_without_term(guardian, limit)
  #   end
  def register_hashtag_data_source(klass)
    DiscoursePluginRegistry.register_hashtag_autocomplete_data_source(klass, self)
  end

  ##
  # Used to set up the priority ordering of hashtag autocomplete results by
  # type using HashtagAutocompleteService.
  #
  # @param {String} type - Roughly corresponding to a model, can only be registered once
  #                        per context. The `category` and `tag` types are registered
  #                        for the `topic-composer` context by default in that priority order.
  # @param {String} context - The context in which the hashtag lookup or search is happening
  #                           in. For example, the Discourse composer context is `topic-composer`.
  #                           Different contexts may want to have different priority orderings
  #                           for certain types of hashtag result.
  # @param {Integer} priority - A number value for ordering type results when hashtag searches
  #                             or lookups occur. Priority is ordered by DESCENDING order.
  def register_hashtag_type_priority_for_context(type, context, priority)
    DiscoursePluginRegistry.register_hashtag_autocomplete_contextual_type_priority(
      { type: type, context: context, priority: priority },
      self,
    )
  end

  ##
  # Register a block that will be called when the UserDestroyer runs
  # with the :delete_posts opt set to true. It's important to note that the block will
  # execute before any other :delete_posts actions, it allows us to manipulate flags
  # before agreeing with them. For example, discourse-akismet makes use of this
  #
  # @param {Block} callback to be called with the user, guardian, and the destroyer opts as arguments
  def register_user_destroyer_on_content_deletion_callback(callback)
    DiscoursePluginRegistry.register_user_destroyer_on_content_deletion_callback(callback, self)
  end

  ##
  # Register a class that implements [BaseBookmarkable], which represents another
  # [ActiveRecord::Model] that may be bookmarked via the [Bookmark] model's
  # polymorphic association. The class handles create and destroy hooks, querying,
  # and reminders among other things.
  def register_bookmarkable(klass)
    return if Bookmark.registered_bookmarkable_from_type(klass.model.name).present?
    DiscoursePluginRegistry.register_bookmarkable(RegisteredBookmarkable.new(klass), self)
  end

  ##
  # Register an object that inherits from [Summarization::Base], which provides a way
  # to summarize content. Staff can select which strategy to use
  # through the `summarization_strategy` setting.
  def register_summarization_strategy(strategy)
    if !strategy.class.ancestors.include?(Summarization::Base)
      raise ArgumentError.new("Not a valid summarization strategy")
    end
    DiscoursePluginRegistry.register_summarization_strategy(strategy, self)
  end

  protected

  def self.js_path
    File.expand_path "#{Rails.root}/app/assets/javascripts/plugins"
  end

  def js_file_path
    "#{Plugin::Instance.js_path}/#{directory_name}.js.erb"
  end

  def extra_js_file_path
    @extra_js_file_path ||= "#{Plugin::Instance.js_path}/#{directory_name}_extra.js.erb"
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
      opts[:client_locale_file] = Dir["#{root_path}/config/locales/client*.#{locale}.yml"].first ||
        ""
      opts[:server_locale_file] = Dir["#{root_path}/config/locales/server*.#{locale}.yml"].first ||
        ""
      opts[:js_locale_file] = File.join(root_path, "assets/locales/#{locale}.js.erb")

      locale_chain = opts[:fallbackLocale] ? [locale, opts[:fallbackLocale]] : [locale]
      lib_locale_path = File.join(root_path, "lib/javascripts/locale")

      path = File.join(lib_locale_path, "message_format")
      opts[:message_format] = find_locale_file(locale_chain, path)
      opts[:message_format] = JsLocaleHelper.find_message_format_locale(
        locale_chain,
        fallback_to_english: false,
      ) unless opts[:message_format]

      path = File.join(lib_locale_path, "moment_js")
      opts[:moment_js] = find_locale_file(locale_chain, path)
      opts[:moment_js] = JsLocaleHelper.find_moment_locale(locale_chain) unless opts[:moment_js]

      path = File.join(lib_locale_path, "moment_js_timezones")
      opts[:moment_js_timezones] = find_locale_file(locale_chain, path)
      opts[:moment_js_timezones] = JsLocaleHelper.find_moment_locale(
        locale_chain,
        timezone_names: true,
      ) unless opts[:moment_js_timezones]

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
    reloadable_patch { NewPostManager.add_plugin_payload_attribute(attribute_name) }
  end

  def register_topic_preloader_associations(fields)
    DiscoursePluginRegistry.register_topic_preloader_association(fields, self)
  end

  def register_search_group_query_callback(callback)
    DiscoursePluginRegistry.register_search_groups_set_query_callback(callback, self)
  end

  private

  def validate_directory_column_name(column_name)
    match = /\A[_a-z]+\z/.match(column_name)
    unless match
      raise "Invalid directory column name '#{column_name}'. Can only contain a-z and underscores"
    end
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
      File.exist?(custom_locale[:js_locale_file]) && custom_locale[:message_format] &&
      custom_locale[:moment_js]
  end

  def find_locale_file(locale_chain, path)
    locale_chain.each do |locale|
      filename = File.join(path, "#{locale}.js")
      return locale, filename if File.exist?(filename)
    end
    nil
  end

  def register_permitted_bulk_action_parameter(name)
    DiscoursePluginRegistry.register_permitted_bulk_action_parameter(name, self)
  end
end
