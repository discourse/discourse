# frozen_string_literal: true

require "middleware/early_hints"

if ENV['DISCOURSE_EARLY_HINTS']
  Rails.configuration.middleware.insert_before Middleware::AnonymousCache, Middleware::EarlyHints
end
