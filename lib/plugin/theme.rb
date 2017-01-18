class Plugin::Theme
  attr_reader :color_scheme

  def initialize(plugin, name)
    @plugin = plugin
    @name = name
  end

  def css(name)
    @plugin.register_asset("stylesheets/#{name}.scss")
  end

  def set_color_scheme(scheme)
    @color_scheme = scheme
  end

  def register_public
    public_dir = "#{@plugin.directory}/public"
    if File.exist?(public_dir)
      Rails.application.config.before_initialize do |app|
        app.middleware.insert_before(
          ::Rack::Runtime,
          ::ActionDispatch::Static,
          public_dir
        )
      end
    end
  end
end

