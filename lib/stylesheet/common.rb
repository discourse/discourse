require 'sassc'

module Stylesheet
  unless defined?(ASSET_ROOT)
    ASSET_ROOT = "#{Rails.root}/app/assets/stylesheets"
  end
end
