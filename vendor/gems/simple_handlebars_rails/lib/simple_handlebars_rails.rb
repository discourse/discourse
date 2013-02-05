require 'sprockets'
require 'sprockets/engines'
require 'simple_handlebars_rails/simple_handlebars_template'

module SimpleHandlebarsRails
  class Engine < Rails::Engine
  end

  Sprockets.register_engine '.shbrs', SimpleHandlebarsTemplate
end