#
#  A class that handles interaction between a plugin and the Discourse App.
#
class DiscoursePluginRegistry

  class << self
    attr_accessor :javascripts
    attr_accessor :server_side_javascripts
    attr_accessor :admin_javascripts
    attr_accessor :stylesheets
    attr_accessor :handlebars

    # Default accessor values
    def javascripts
      @javascripts ||= Set.new
    end

    def admin_javascripts
      @admin_javascripts ||= Set.new
    end

    def server_side_javascripts
      @server_side_javascripts ||= Set.new
    end

    def stylesheets
      @stylesheets ||= Set.new
    end

    def handlebars
      @handlebars ||= Set.new
    end
  end

  def register_js(filename, options={})
    # If we have a server side option, add that too.
    self.class.server_side_javascripts << options[:server_side] if options[:server_side].present?
    self.class.javascripts << filename
  end

  def register_css(filename)
    self.class.stylesheets << filename
  end

  def register_archetype(name, options={})
    Archetype.register(name, options)
  end

  def javascripts
    self.class.javascripts
  end

  def server_side_javascripts
    self.class.server_side_javascripts
  end

  def stylesheets
    self.class.stylesheets
  end

  def handlebars
    self.class.handlebars
  end

  def self.clear
    self.javascripts = nil
    self.server_side_javascripts = nil
    self.stylesheets = nil
    self.handlebars = nil
  end

  def self.setup(plugin_class)
    registry = DiscoursePluginRegistry.new
    plugin = plugin_class.new(registry)
    plugin.setup
  end

  def self.last_changed_marker(format)
    "#{Rails.root}/plugins/.plugindata/assets/last_changed.#{format}"
  end

  def self.touch_js_marker
    path = last_changed_marker(:js)
    touch(path, Time.now)
  end

  def self.touch_css_marker
    path = last_changed_marker(:css)
    touch(path, Time.now)
  end

  private

  # from FileUtils gem
  # http://apidock.com/ruby/FileUtils/touch/class#source
  def self.touch(path, time)
    created = false
    begin
      File.utime(time, time, path)
    rescue Errno::ENOENT
      raise if created
      File.open(path, 'a') {
        ;
      }
      created = true
      retry
    end
  end
end
