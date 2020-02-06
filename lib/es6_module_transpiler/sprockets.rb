# frozen_string_literal: true

require 'sprockets'
require 'discourse_js_processor'

Sprockets.register_mime_type 'application/javascript', extensions: ['.js', '.es6', '.js.es6', '.js.no-module.es6'], charset: :unicode
Sprockets.register_postprocessor 'application/javascript', DiscourseJsProcessor
