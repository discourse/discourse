# frozen_string_literal: true

require 'rack/protection'

Rails.configuration.middleware.use Rack::Protection::FrameOptions
