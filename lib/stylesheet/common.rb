# frozen_string_literal: true

require 'sassc'

module Stylesheet
  ASSET_ROOT = "#{Rails.root}/app/assets/stylesheets" unless defined? ASSET_ROOT
end
