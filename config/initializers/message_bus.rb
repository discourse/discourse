MessageBus.site_id_lookup do 
  RailsMultisite::ConnectionManagement.current_db
end

MessageBus.user_id_lookup do |env|
  request = Rack::Request.new(env)
  auth_token = request.cookies["_t"]
  user = nil
  if auth_token && auth_token.length == 32
    user = User.where(auth_token: auth_token).first 
  end
  user.id if user
end

MessageBus.on_connect do |site_id|
  RailsMultisite::ConnectionManagement.establish_connection(:db => site_id)
end

MessageBus.on_disconnect do |site_id|
  ActiveRecord::Base.connection_handler.clear_active_connections!
end

# Point at our redis
MessageBus.redis_config = YAML::load(File.open("#{Rails.root}/config/redis.yml"))[Rails.env].symbolize_keys

MessageBus.long_polling_enabled = SiteSetting.enable_long_polling
MessageBus.long_polling_interval = SiteSetting.long_polling_interval
