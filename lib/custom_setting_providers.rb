# Support for plugins to register custom setting providers. They can do this
# by having a file, `register_provider.rb` in their root that will be run
# at this point.

Dir.glob(File.join(File.dirname(__FILE__), '../plugins', '*', "register_provider.rb")) do |p|
  require p
end
