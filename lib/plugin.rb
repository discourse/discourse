require_dependency 'auth_provider'
require 'digest/sha1'
require 'fileutils'

class Plugin

  METADATA = [:name, :about, :version, :authors]

  attr_accessor :path
  attr_accessor *METADATA
  attr_reader :auth_providers
  attr_reader :assets

  def self.find_all(parent_path)
    plugins = []
    Dir["#{parent_path}/**/plugin.rb"].each do |path|
      plugin = parse(File.read(path))
      plugin.path = path
      plugins << plugin
    end

    plugins
  end

  def self.parse(text)
    plugin = self.new

    text.each_line do |line|
      break unless plugin.parse_line(line)
    end

    plugin
  end

  def initialize
    @assets = []
  end

  def parse_line(line)
    line = line.strip

    unless line.empty?
      return false unless line[0] == "#"
      attribute, *description = line[1..-1].split(":")

      description = description.join(":")
      attribute = attribute.strip.to_sym

      if METADATA.include?(attribute)
        self.send("#{attribute}=", description.strip)
      end
    end

    true
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
    js = "(function(){"

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

    js << "})();"

    # TODO don't serve blank assets
    [[css,"css"],[js,"js"]].map do |asset, extension|
      hash = Digest::SHA1.hexdigest asset
      ["#{auto_generated_path}/plugin_#{hash}.#{extension}", asset]
    end

  end

  # note, we need to be able to parse seperately to activation.
  # this allows us to present information about a plugin in the UI
  # prior to activations
  def activate!
    self.instance_eval File.read(path)
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

  def auth_provider(type, opts)
    @auth_providers ||= []
    provider = AuthProvider.new
    provider.type = type
    [:name, :glyph, :background_color, :title, :message, :frame_width, :frame_height].each do |sym|
      provider.send "#{sym}=", opts.delete(sym)
    end
    provider.options = opts
    @auth_providers << provider
  end
end
