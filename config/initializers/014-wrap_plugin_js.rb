require 'discourse_wrap_plugin_js'

Rails.application.config.assets.configure do |env|
  env.register_preprocessor('application/javascript', DiscourseWrapPluginJS)
end
