require 'digest/sha1'
require 'fileutils'
require_dependency 'plugin/metadata'
require_dependency 'plugin/auth_provider'

class Plugin::Instance

  attr_accessor :path, :metadata
  attr_reader :admin_route

  # Memoized array readers
  [:assets, :auth_providers, :color_schemes, :initializers, :javascripts, :styles].each do |att|
    class_eval %Q{
      def #{att}
        @#{att} ||= []
      end
    }
  end

  # Memoized hash readers
  [:seed_data, :emojis].each do |att|
    class_eval %Q{
      def #{att}
        @#{att} ||= HashWithIndifferentAccess.new({})
      end
    }
  end

  def self.find_all(parent_path)
    [].tap { |plugins|
      # also follows symlinks - http://stackoverflow.com/q/357754
      Dir["#{parent_path}/**/*/**/plugin.rb"].sort.each do |path|

        # tagging is included in core, so don't load it
        next if path =~ /discourse-tagging/

        source = File.read(path)
        metadata = Plugin::Metadata.parse(source)
        plugins << self.new(metadata, path)
      end
    }
  end

  def initialize(metadata=nil, path=nil)
    @metadata = metadata
    @path = path
    @idx = 0
  end

  def add_admin_route(label, location)
    @admin_route = {label: label, location: location}
  end

  def enabled?
    @enabled_site_setting ? SiteSetting.send(@enabled_site_setting) : true
  end

  delegate :name, to: :metadata

  def add_to_serializer(serializer, attr, define_include_method=true, &block)
    klass = "#{serializer.to_s.classify}Serializer".constantize rescue "#{serializer.to_s}Serializer".constantize

    klass.attributes(attr) unless attr.to_s.start_with?("include_")

    klass.send(:define_method, attr, &block)

    return unless define_include_method

    # Don't include serialized methods if the plugin is disabled
    plugin = self
    klass.send(:define_method, "include_#{attr}?") { plugin.enabled? }
  end

  def whitelist_staff_user_custom_field(field)
    User.register_plugin_staff_custom_field(field, self)
  end

  # Extend a class but check that the plugin is enabled
  # for class methods use `add_class_method`
  def add_to_class(klass, attr, &block)
    klass = klass.to_s.classify.constantize rescue klass.to_s.constantize

    hidden_method_name = :"#{attr}_without_enable_check"
    klass.send(:define_method, hidden_method_name, &block)

    plugin = self
    klass.send(:define_method, attr) do |*args|
      send(hidden_method_name, *args) if plugin.enabled?
    end
  end

  # Adds a class method to a class, respecting if plugin is enabled
  def add_class_method(klass, attr, &block)
    klass = klass.to_s.classify.constantize rescue klass.to_s.constantize

    hidden_method_name = :"#{attr}_without_enable_check"
    klass.send(:define_singleton_method, hidden_method_name, &block)

    plugin = self
    klass.send(:define_singleton_method, attr) do |*args|
      send(hidden_method_name, *args) if plugin.enabled?
    end
  end

  def add_model_callback(klass, callback, &block)
    klass = klass.to_s.classify.constantize rescue klass.to_s.constantize
    plugin = self

    # generate a unique method name
    method_name = "#{plugin.name}_#{klass.name}_#{callback}#{@idx}".underscore
    @idx += 1
    hidden_method_name = :"#{method_name}_without_enable_check"
    klass.send(:define_method, hidden_method_name, &block)

    klass.send(callback) do |*args|
      send(hidden_method_name, *args) if plugin.enabled?
    end

  end

  # Add validation method but check that the plugin is enabled
  def validate(klass, name, &block)
    klass = klass.to_s.classify.constantize
    klass.send(:define_method, name, &block)

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
      assets << [path]
    end

    delete_extra_automatic_assets(paths)

    assets
  end

  def delete_extra_automatic_assets(good_paths)
    return unless Dir.exists? auto_generated_path

    filenames = good_paths.map{|f| File.basename(f)}
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

  def auto_generated_path
    File.dirname(path) << "/auto_generated"
  end

  def after_initialize(&block)
    initializers << block
  end

  # A proxy to `DiscourseEvent.on` which does nothing if the plugin is disabled
  def on(event_name, &block)
    DiscourseEvent.on(event_name) do |*args|
      block.call(*args) if enabled?
    end
  end

  def notify_after_initialize
    color_schemes.each do |c|
      ColorScheme.create_from_base(name: c[:name], colors: c[:colors]) unless ColorScheme.where(name: c[:name]).exists?
    end

    initializers.each do |callback|
      begin
        callback.call(self)
      rescue ActiveRecord::StatementInvalid => e
        # When running db:migrate for the first time on a new database, plugin initializers might
        # try to use models. Tolerate it.
        raise e unless e.message.try(:include?, "PG::UndefinedTable")
      end
    end
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

  def register_custom_html(hash)
    DiscoursePluginRegistry.custom_html ||= {}
    DiscoursePluginRegistry.custom_html.merge!(hash)
  end

  def register_asset(file, opts=nil)
    full_path = File.dirname(path) << "/assets/" << file
    assets << [full_path, opts]
  end

  def register_color_scheme(name, colors)
    color_schemes << {name: name, colors: colors}
  end

  def register_seed_data(key, value)
    seed_data[key] = value
  end

  def register_emoji(name, url)
    emojis[name] = url
  end

  def automatic_assets
    css = styles.join("\n")
    js = javascripts.join("\n")

    auth_providers.each do |auth|

      auth_json = auth.to_json
      hash = Digest::SHA1.hexdigest(auth_json)
      js << <<JS
define("discourse/initializers/login-method-#{hash}",
  ["discourse/models/login-method", "exports"],
  function(module, __exports__) {
    "use strict";
    __exports__["default"] = {
      name: "login-method-#{hash}",
      after: "inject-objects",
      initialize: function() {
        if (Ember.testing) { return; }
        module.register(#{auth_json});
      }
    };
  });
JS

      if auth.glyph
        css << ".btn-social.#{auth.name}:before{ content: '#{auth.glyph}'; }\n"
      end

      if auth.background_color
        css << ".btn-social.#{auth.name}{ background: #{auth.background_color}; }\n"
      end
    end

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

  # note, we need to be able to parse seperately to activation.
  # this allows us to present information about a plugin in the UI
  # prior to activations
  def activate!

    if @path
      # Automatically include all ES6 JS and hbs files
      root_path = "#{File.dirname(@path)}/assets/javascripts"
      DiscoursePluginRegistry.register_glob(root_path, 'js.es6')
      DiscoursePluginRegistry.register_glob(root_path, 'hbs')

      admin_path = "#{File.dirname(@path)}/admin/assets/javascripts"
      DiscoursePluginRegistry.register_glob(admin_path, 'js.es6', admin: true)
      DiscoursePluginRegistry.register_glob(admin_path, 'hbs', admin: true)
    end

    self.instance_eval File.read(path), path
    if auto_assets = generate_automatic_assets!
      assets.concat(auto_assets)
    end

    register_assets! unless assets.blank?

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
    Rails.configuration.paths["db/migrate"] << File.dirname(path) + "/db/migrate"

    public_data = File.dirname(path) + "/public"
    if Dir.exists?(public_data)
      target = Rails.root.to_s + "/public/plugins/"
      `mkdir -p #{target}`
      target << name.gsub(/\s/,"_")
      # TODO a cleaner way of registering and unregistering
      `rm -f #{target}`
      `ln -s #{public_data} #{target}`
    end
  end


  def auth_provider(opts)
    provider = Plugin::AuthProvider.new

    Plugin::AuthProvider.auth_attributes.each do |sym|
      provider.send "#{sym}=", opts.delete(sym)
    end
    auth_providers << provider
  end


  # shotgun approach to gem loading, in future we need to hack bundler
  #  to at least determine dependencies do not clash before loading
  #
  # Additionally we want to support multiple ruby versions correctly and so on
  #
  # This is a very rough initial implementation
  def gem(name, version, opts = {})
    gems_path = File.dirname(path) + "/gems/#{RUBY_VERSION}"
    spec_path = gems_path + "/specifications"
    spec_file = spec_path + "/#{name}-#{version}.gemspec"
    unless File.exists? spec_file
      command = "gem install #{name} -v #{version} -i #{gems_path} --no-document --ignore-dependencies"
      if opts[:source]
        command << " --source #{opts[:source]}"
      end
      puts command
      puts `#{command}`
    end
    if File.exists? spec_file
      spec = Gem::Specification.load spec_file
      spec.activate
      unless opts[:require] == false
        require opts[:require_name] ? opts[:require_name] : name
      end
    else
      puts "You are specifying the gem #{name} in #{path}, however it does not exist!"
      exit(-1)
    end
  end

  def enabled_site_setting(setting=nil)
    if setting
      @enabled_site_setting = setting
    else
      @enabled_site_setting
    end
  end

  protected

  def register_assets!
    assets.each do |asset, opts|
      DiscoursePluginRegistry.register_asset(asset, opts)
    end
  end

  private

  def write_asset(path, contents)
    unless File.exists?(path)
      ensure_directory(path)
      File.open(path,"w") { |f| f.write(contents) }
    end
  end

end
