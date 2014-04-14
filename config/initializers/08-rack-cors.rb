if GlobalSetting.enable_cors
  require 'rack/cors'

  Rails.configuration.middleware.use Rack::Cors do
    allow do
      origins GlobalSetting.cors_origin
      resource '*', headers: :any, methods: [:get, :post, :options]
    end
  end
end
