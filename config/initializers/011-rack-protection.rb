# frozen_string_literal: true

require 'rack/protection'

Rails.configuration.middleware.use Middleware::FrameOptions
