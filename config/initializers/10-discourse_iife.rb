require 'discourse_iife'

Rails.application.assets.register_preprocessor('application/javascript', DiscourseIIFE)
unless Rails.env.production?
  require 'source_url'
  Rails.application.assets.register_postprocessor('application/javascript', SourceURL)
end
