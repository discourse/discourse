# frozen_string_literal: true

module Stylesheet
  module ScssFunctions
    def asset_url(path)
      Discourse.deprecate("The `asset-url` SCSS function is deprecated. Use `absolute-image-url` instead.", drop_from: '2.9.0')
      SassC::Script::Value::String.new("url('#{ActionController::Base.helpers.asset_url(path.value)}')")
    end
    def image_url(path)
      Discourse.deprecate("The `image-url` SCSS function is deprecated. Use `absolute-image-url` instead.", drop_from: '2.9.0')
      SassC::Script::Value::String.new("url('#{ActionController::Base.helpers.image_url(path.value)}')")
    end
  end
end

::SassC::Script::Functions.include(Stylesheet::ScssFunctions)
