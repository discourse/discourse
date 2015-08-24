MessageBus.site_id_lookup do
  RailsMultisite::ConnectionManagement.current_db
end

MessageBus.extra_response_headers_lookup do |env|
  {
    "Access-Control-Allow-Origin" => Discourse.base_url_no_prefix,
    "Access-Control-Allow-Methods" => "GET, POST",
    "Access-Control-Allow-Headers" => "X-SILENCE-LOGGER, X-Shared-Session-Key"
  }
end

MessageBus.user_id_lookup do |env|
  user = CurrentUser.lookup_from_env(env)
  user.id if user
end

MessageBus.group_ids_lookup do |env|
  user = CurrentUser.lookup_from_env(env)
  if user && user.admin?
    # special rule, admin is allowed access to all groups
    Group.pluck(:id)
  elsif user
    user.groups.pluck('groups.id')
  end
end

MessageBus.on_connect do |site_id|
  RailsMultisite::ConnectionManagement.establish_connection(db: site_id)
end

MessageBus.on_disconnect do |site_id|
  ActiveRecord::Base.connection_handler.clear_active_connections!
end

# Point at our redis
MessageBus.redis_config = GlobalSetting.redis_config

MessageBus.long_polling_enabled = SiteSetting.enable_long_polling
MessageBus.long_polling_interval = SiteSetting.long_polling_interval

MessageBus.is_admin_lookup do |env|
  user = CurrentUser.lookup_from_env(env)
  if user && user.admin
    true
  else
    false
  end
end

MessageBus.cache_assets = !Rails.env.development?
MessageBus.enable_diagnostics

if Rails.env == "test"
  # disable keepalive in testing
  MessageBus.keepalive_interval = -1
end
