require 'discourse_iife'

Rails.application.assets.register_preprocessor('application/javascript', DiscourseIIFE)