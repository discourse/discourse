if Rails.configuration.respond_to?(:enable_rack_cors) && Rails.configuration.enable_rack_cors
  require 'rack/cors'

  cors_origins  = Rails.configuration.respond_to?(:rack_cors_origins) ? Rails.configuration.rack_cors_origins : ['*']
  cors_resource = Rails.configuration.respond_to?(:rack_cors_resource) ? Rails.configuration.rack_cors_resource : ['*', { headers: :any, methods: [:get, :post, :options] }]

  Rails.configuration.middleware.use Rack::Cors do
    allow do
      origins *cors_origins
      resource *cors_resource
    end
  end
end
