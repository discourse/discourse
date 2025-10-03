# frozen_string_literal: true

if GlobalSetting.skip_redis?
  MessageBus.configure(backend: :memory)
  return
end

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

  ::Middleware::RequestTracker.populate_request_queue_seconds!(env)

  if queue_time = env["REQUEST_QUEUE_SECONDS"]
    if queue_time > (GlobalSetting.reject_message_bus_queue_seconds).to_f
      raise RateLimiter::LimitExceeded, 30 + (rand * 120).to_i
    end
  end

  host = RailsMultisite::ConnectionManagement.host(env)
  RailsMultisite::ConnectionManagement.with_hostname(host) do
    cors_origin = Discourse.base_url_no_prefix

    if GlobalSetting.enable_cors && SiteSetting.cors_origins.present?
      allowed_origins = SiteSetting.cors_origins_map
      cors_origin = env["HTTP_ORIGIN"] if allowed_origins.include?(env["HTTP_ORIGIN"])
    end

    extra_headers = {
      "Access-Control-Allow-Origin" => cors_origin,
      "Access-Control-Allow-Methods" => "GET, POST",
      "Access-Control-Allow-Headers" =>
        "X-SILENCE-LOGGER, X-Shared-Session-Key, Dont-Chunk, Discourse-Present, Discourse-Deferred-Track-View",
      "Access-Control-Max-Age" => "7200",
    }

    user = nil
    begin
      user = CurrentUser.lookup_from_env(env)
    rescue Discourse::InvalidAccess => e
      # this is bad we need to remove the cookie
      if e.opts[:delete_cookie].present?
        extra_headers["Set-Cookie"] = "_t=del; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT"
      end
    rescue => e
      Discourse.warn_exception(e, message: "Unexpected error in Message Bus", env: env)
    end

    user_id = user && user.id

    raise Discourse::InvalidAccess if !user_id && SiteSetting.login_required

    is_admin = !!(user && user.admin?)
    group_ids =
      if is_admin
        # special rule, admin is allowed access to all groups
        Group.pluck(:id)
      elsif user
        user.groups.pluck("groups.id")
      end

    extra_headers["Discourse-Logged-Out"] = "1" if env[Auth::DefaultCurrentUserProvider::BAD_TOKEN]

    if Rails.env.development?
      # Adding no-transform prevents the expressjs ember-cli proxy buffering/compressing the response
      extra_headers["Cache-Control"] = "no-transform, must-revalidate, private, max-age=0"
    end

    hash = {
      extra_headers: extra_headers,
      user_id: user_id,
      group_ids: group_ids,
      is_admin: is_admin,
      site_id: RailsMultisite::ConnectionManagement.current_db,
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
    [429, { "Retry-After" => e.available_in.to_s }, [e.description]]
  end
end

MessageBus.on_connect do |site_id|
  RailsMultisite::ConnectionManagement.establish_connection(db: site_id)
end

MessageBus.on_disconnect do |site_id|
  ActiveRecord::Base.connection_handler.clear_active_connections!
end

if Rails.env == "test"
  MessageBus.configure(backend: :memory)
else
  MessageBus.redis_config = GlobalSetting.message_bus_redis_config
end

MessageBus.backend_instance.max_backlog_size = GlobalSetting.message_bus_max_backlog_size
MessageBus.backend_instance.clear_every = GlobalSetting.message_bus_clear_every
MessageBus.long_polling_enabled =
  GlobalSetting.enable_long_polling.nil? ? true : GlobalSetting.enable_long_polling
MessageBus.long_polling_interval = GlobalSetting.long_polling_interval || 25_000

if Rails.env == "test" || $0 =~ /rake$/
  # disable keepalive in testing
  MessageBus.keepalive_interval = -1
end
