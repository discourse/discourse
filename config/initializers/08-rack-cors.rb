if GlobalSetting.enable_cors
  require 'rack/cors'

  Rails.configuration.middleware.use Rack::Cors do
    allow do
      origins GlobalSetting.cors_origin.split(',').map(&:strip)
      resource '*', headers: :any, methods: [:get, :post, :options]
    end
  end
end
