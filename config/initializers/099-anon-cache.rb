# frozen_string_literal: true

require "middleware/anonymous_cache"

enabled =
  if Rails.configuration.respond_to?(:enable_anon_caching)
    Rails.configuration.enable_anon_caching
  else
    Rails.env.production?
  end

if !ENV['DISCOURSE_DISABLE_ANON_CACHE'] && enabled
  # in an ideal world this is position 0, but mobile detection uses ... session and request and params
  Rails.configuration.middleware.insert_after ActionDispatch::Flash, Middleware::AnonymousCache
end
