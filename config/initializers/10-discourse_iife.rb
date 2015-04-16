require 'discourse_iife'
require 'source_url'

Rails.application.assets.register_preprocessor('application/javascript', DiscourseIIFE)
Rails.application.assets.register_postprocessor('application/javascript', SourceURL)
