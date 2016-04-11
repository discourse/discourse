require 'discourse_iife'

Rails.application.config.assets.configure do |env|
  env.register_preprocessor('application/javascript', DiscourseIIFE)
end

unless Rails.env.production? || ENV["DISABLE_EVAL"]
  require 'source_url'
  Rails.application.config.assets.register_postprocessor('application/javascript', SourceURL)
end
