# frozen_string_literal: true

require 'sassc'

module Stylesheet
  module Common
    ASSET_ROOT = "#{Rails.root}/app/assets/stylesheets" unless defined? ASSET_ROOT
  end
end
