module Stylesheet
  module ScssFunctions
    def asset_url(path)
      SassC::Script::String.new("url('#{ActionController::Base.helpers.asset_path(path.value)}')")
    end
  end
end

::SassC::Script::Functions.send :include, Stylesheet::ScssFunctions
