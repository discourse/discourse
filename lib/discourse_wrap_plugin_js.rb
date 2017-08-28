class DiscourseWrapPluginJS
  def initialize(options = {}, &block)
  end

  def self.instance
    @instance ||= new
  end

  def self.call(input)
    instance.call(input)
  end

  # Add stuff around javascript
  def call(input)
    path = input[:environment].context_class.new(input).pathname.to_s
    data = input[:data]

    # Only apply to plugin paths
    return data unless (path =~ /\/plugins\//)

    # Find the folder name of the plugin
    folder_name = path[/\/plugins\/(\S+?)\//, 1]

    # Lookup plugin name
    plugin = Discourse.plugins.find { |p| p.path =~ /\/plugins\/#{folder_name}\// }
    plugin_name = plugin.name

    "Discourse._registerPluginScriptDefinition('#{plugin_name}', function(){#{data}}); \n"
  end

end
