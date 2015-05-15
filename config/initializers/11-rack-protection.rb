require 'rack/protection'

Rails.configuration.middleware.use Rack::Protection::FrameOptions
