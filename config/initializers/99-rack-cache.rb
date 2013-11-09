require_dependency "middleware/anonymous_cache"

enabled = if Rails.configuration.respond_to?(:enable_anon_caching)
            Rails.configuration.enable_anon_caching
          else
            Rails.env.production?
          end

if enabled
  Rails.configuration.middleware.insert 0, Middleware::AnonymousCache
end

