module Stylesheet
  module ScssFunctions
    def asset_url(path)
      SassC::Script::String.new("url('#{ActionController::Base.helpers.asset_url(path.value)}')")
    end
    def image_url(path)
      SassC::Script::String.new("url('#{ActionController::Base.helpers.image_url(path.value)}')")
    end
  end
end

::SassC::Script::Functions.send :include, Stylesheet::ScssFunctions
