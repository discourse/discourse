# frozen_string_literal: true

module Stylesheet
  module ScssFunctions
    def asset_url(path)
      SassC::Script::Value::String.new("url('#{ActionController::Base.helpers.asset_url(path.value)}')")
    end
    def image_url(path)
      SassC::Script::Value::String.new("url('#{ActionController::Base.helpers.image_url(path.value)}')")
    end
  end
end

::SassC::Script::Functions.include(Stylesheet::ScssFunctions)
