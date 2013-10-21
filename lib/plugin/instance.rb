require 'digest/sha1'
require 'fileutils'
require_dependency 'plugin/metadata'
require_dependency 'plugin/auth_provider'

class Plugin::Instance

  attr_reader :auth_providers, :assets
  attr_accessor :path, :metadata

  def self.find_all(parent_path)
    [].tap { |plugins|
      # also follows symlinks - http://stackoverflow.com/q/357754
      Dir["#{parent_path}/**/*/**/plugin.rb"].each do |path|
        source = File.read(path)
        metadata = Plugin::Metadata.parse(source)
        plugins << self.new(metadata, path)
      end
    }
  end

  def initialize(metadata=nil, path=nil)
    @metadata = metadata
    @path = path
    @assets = []
  end

  def name
    metadata.name
  end

  # will make sure all the assets this plugin needs are registered
  def generate_automatic_assets!
    paths = []
    automatic_assets.each do |path, contents|
      unless File.exists? path
        ensure_directory path
        File.open(path,"w") do |f|
          f.write(contents)
        end
      end
      paths << path
    end

    delete_extra_automatic_assets(paths)

    paths
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
    @after_initialize ||= []
    @after_initialize << block
  end

  def notify_after_initialize
    if @after_initialize
      @after_initialize.each do |callback|
        callback.call
      end
    end
  end

  def register_css(style)
    @styles ||= []
    @styles << style
  end

  def register_javascript(js)
    @javascripts ||= []
    @javascripts << js
  end


  def register_asset(file,opts=nil)
    full_path = File.dirname(path) << "/assets/" << file
    assets << full_path
    if opts == :server_side
      @server_side_javascripts ||= []
      @server_side_javascripts << full_path
    end
  end

  def automatic_assets
    css = ""
    js = ""

    css = @styles.join("\n") if @styles
    js = @javascripts.join("\n") if @javascripts

    unless auth_providers.blank?
      auth_providers.each do |auth|
        overrides = ""
        overrides = ", titleOverride: '#{auth.title}'" if auth.title
        overrides << ", messageOverride: '#{auth.message}'" if auth.message
        overrides << ", frameWidth: '#{auth.frame_width}'" if auth.frame_width
        overrides << ", frameHeight: '#{auth.frame_height}'" if auth.frame_height

        js << "Discourse.LoginMethod.register(Discourse.LoginMethod.create({name: '#{auth.name}'#{overrides}}));\n"

        if auth.glyph
          css << ".btn-social.#{auth.name}:before{ content: '#{auth.glyph}'; }\n"
        end

        if auth.background_color
          css << ".btn-social.#{auth.name}{ background: #{auth.background_color}; }\n"
        end
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
    self.instance_eval File.read(path), path
    if auto_assets = generate_automatic_assets!
      assets.concat auto_assets
    end
    unless assets.blank?
      assets.each do |asset|
        if asset =~ /\.js$/
          DiscoursePluginRegistry.javascripts << asset
        elsif asset =~ /\.css$|\.scss$/
          DiscoursePluginRegistry.stylesheets << asset
        end
      end

      # TODO possibly amend this to a rails engine
      Rails.configuration.assets.paths << auto_generated_path
      Rails.configuration.assets.paths << File.dirname(path) + "/assets"
    end

    if @server_side_javascripts
      @server_side_javascripts.each do |js|
        DiscoursePluginRegistry.server_side_javascripts << js
      end
    end
  end

  def auth_provider(opts)
    @auth_providers ||= []
    provider = Plugin::AuthProvider.new
    [:glyph, :background_color, :title, :message, :frame_width, :frame_height, :authenticator].each do |sym|
      provider.send "#{sym}=", opts.delete(sym)
    end
    @auth_providers << provider
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
      command = "gem install #{name} -v #{version} -i #{gems_path} --no-rdoc --no-ri"
      puts command
      puts `#{command}`
    end
    if File.exists? spec_file
      spec = Gem::Specification.load spec_file
      spec.activate
      unless opts[:require] == false
        require name
      end
    else
      puts "You are specifying the gem #{name} in #{path}, however it does not exist!"
      exit -1
    end
  end

end
