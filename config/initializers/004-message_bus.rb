MessageBus.site_id_lookup do |env = nil|
  if env
    setup_message_bus_env(env)
    env["__mb"][:site_id]
  else
    RailsMultisite::ConnectionManagement.current_db
  end
end

def setup_message_bus_env(env)
  return if env["__mb"]

  host = RailsMultisite::ConnectionManagement.host(env)
  RailsMultisite::ConnectionManagement.with_hostname(host) do
    extra_headers = {
      "Access-Control-Allow-Origin" => Discourse.base_url_no_prefix,
      "Access-Control-Allow-Methods" => "GET, POST",
      "Access-Control-Allow-Headers" => "X-SILENCE-LOGGER, X-Shared-Session-Key, Dont-Chunk, Discourse-Visible"
    }

    user = nil
    begin
      user = CurrentUser.lookup_from_env(env)
    rescue Discourse::InvalidAccess => e
      # this is bad we need to remove the cookie
      if e.opts[:delete_cookie].present?
        extra_headers['Set-Cookie'] = '_t=del; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT'
      end
    rescue => e
      Discourse.warn_exception(e, message: "Unexpected error in Message Bus")
    end
    user_id = user && user.id
    is_admin = !!(user && user.admin?)
    group_ids = if is_admin
      # special rule, admin is allowed access to all groups
      Group.pluck(:id)
    elsif user
      user.groups.pluck('groups.id')
    end

    if env[Auth::DefaultCurrentUserProvider::BAD_TOKEN]
      extra_headers['Discourse-Logged-Out'] = '1'
    end

    hash = {
      extra_headers: extra_headers,
      user_id: user_id,
      group_ids: group_ids,
      is_admin: is_admin,
      site_id: RailsMultisite::ConnectionManagement.current_db

    }
    env["__mb"] = hash
  end

  nil
end

MessageBus.extra_response_headers_lookup do |env|
  setup_message_bus_env(env)
  env["__mb"][:extra_headers]
end

MessageBus.user_id_lookup do |env|
  setup_message_bus_env(env)
  env["__mb"][:user_id]
end

MessageBus.group_ids_lookup do |env|
  setup_message_bus_env(env)
  env["__mb"][:group_ids]
end

MessageBus.is_admin_lookup do |env|
  setup_message_bus_env(env)
  env["__mb"][:is_admin]
end

MessageBus.on_middleware_error do |env, e|
  if Discourse::InvalidAccess === e
    [403, {}, ["Invalid Access"]]
  elsif RateLimiter::LimitExceeded === e
    [429, { 'Retry-After' => e.available_in }, [e.description]]
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
MessageBus.reliable_pub_sub.max_backlog_size = GlobalSetting.message_bus_max_backlog_size

MessageBus.long_polling_enabled = SiteSetting.enable_long_polling
MessageBus.long_polling_interval = SiteSetting.long_polling_interval
MessageBus.cache_assets = !Rails.env.development?
MessageBus.enable_diagnostics

if Rails.env == "test" || $0 =~ /rake$/
  # disable keepalive in testing
  MessageBus.keepalive_interval = -1
end
