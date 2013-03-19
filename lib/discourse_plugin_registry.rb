#
#  A class that handles interaction between a plugin and the Discourse App.
#
class DiscoursePluginRegistry
  require 'tempfile'
  require 'fileutils'

  class << self
    attr_accessor :javascripts
    attr_accessor :server_side_javascripts
    attr_accessor :stylesheets
  end

  # Default accessor values
  #
  def self.stylesheets
    @stylesheets ||= Set.new
  end

  def self.javascripts
    @javascripts ||= Set.new
  end

  def self.server_side_javascripts
    @server_side_javascripts ||= Set.new
  end

  def register_js(filename, options={})
    # If we have a server side option, add that too.
    self.class.server_side_javascripts << options[:server_side] if options[:server_side].present?

    self.class.javascripts << filename
  end

  def register_css(filename)
    self.class.stylesheets << filename
  end

  def stylesheets
    self.class.stylesheets
  end

  def register_archetype(name, options={})
    Archetype.register(name, options)
  end

  def server_side_javascripts
    self.class.javascripts
  end

  def javascripts
    self.class.javascripts
  end

  def self.clear
    self.stylesheets = nil
    self.server_side_javascripts = nil
    self.javascripts = nil
  end

  def self.setup(plugin_class)
    registry = DiscoursePluginRegistry.new
    plugin = plugin_class.new(registry)
    plugin.setup
  end
  
  def register_nav_item(nav_item_name, reset = false)
    path = Rails.root.join('app','assets','javascripts','discourse','models','nav_item.js')
    temp_file = Tempfile.new('temp-nav')
    begin
      File.open(path, 'r') do |file|
        file.each_line do |line|
          if line.match(/^validNavNames/)
            nav_items =  ExecJS.eval(line.gsub(';',''))
            if nav_items.include?(nav_item_name)
              temp_file.puts line
            elsif reset == true
              temp_file.puts 'validNavNames = ["read", "popular", "categories", "favorited", "category", "unread", "new", "posted"];' + "\n"
            else  
              nav_items << nav_item_name
              temp_file.puts 'validNavNames = ' + nav_items.to_s + ";\n"
            end
          else
            temp_file.puts line  
          end
        end
      end
      temp_file.rewind
      FileUtils.mv(temp_file.path, path)
    ensure
      temp_file.close
      temp_file.unlink
    end
  end
  
  def valid_nav_items
    path = Rails.root.join('app','assets','javascripts','discourse','models','nav_item.js')
    File.open(path, 'r') do |file|
      file.each_line do |line|
        if line.match(/^validNavNames/) 
          @nav_items =  ExecJS.eval(line.gsub(';',''))
        end  
      end
    end 
    @nav_items 
  end
  
  def reset_default_nav_items
    
  end
  
end
