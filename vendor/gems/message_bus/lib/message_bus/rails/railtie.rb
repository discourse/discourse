module MessageBus; module Rails; end; end

class MessageBus::Rails::Railtie < ::Rails::Railtie
  initializer "message_bus.configure_init" do |app|
    MessageBus::MessageHandler.load_handlers("#{Rails.root}/app/message_handlers")
    app.middleware.use MessageBus::Rack::Middleware
    MessageBus.logger = Rails.logger
  end
end
