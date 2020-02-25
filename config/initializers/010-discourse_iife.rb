# frozen_string_literal: true

require 'discourse_iife'

Rails.application.config.assets.configure do |env|
  env.register_preprocessor('application/javascript', DiscourseIIFE)

  unless Rails.env.production?
    require 'source_url'
    env.register_postprocessor('application/javascript', SourceURL)
  end
end
