# frozen_string_literal: true

require "site_settings/deprecated_settings"
require "site_setting_extension"
require "site_settings/yaml_loader"
require "site_settings/defaults_provider"
require "site_settings/validations"
require "site_settings/type_supervisor"
require "enum"
require "regex_setting_validation"
require "string_setting_validator"
require "email_setting_validator"
require "username_setting_validator"
require "group_setting_validator"
require "allow_user_locale_enabled_validator"
require "categories_topics_validator"
require "integer_setting_validator"
require "regex_presence_validator"
require "category_page_style"
require "color_scheme_setting"
require "base_font_setting"
require "enable_invite_only_validator"
require "enable_local_logins_via_email_validator"
require "enable_sso_validator"
require "sso_overrides_email_validator"
require "min_username_length_validator"
require "max_username_length_validator"
require "unicode_username_validator"
require "unicode_username_allowlist_validator"
require "trust_level_setting"
require "enable_private_email_messages_validator"
require "trust_level_and_staff_setting"
require "markdown_typographer_quotation_marks_validator"
require "emoji_set_site_setting"
require "reply_by_email_enabled_validator"
require "reply_by_email_address_validator"
require "alternative_reply_by_email_addresses_validator"
require "pop3_polling_enabled_setting_validator"
require "s3_region_site_setting"
require "external_system_avatars_validator"
require "color_list_validator"
require "selectable_avatars_enabled_validator"
require "reviewable_sensitivity_setting"
require "reviewable_priority_setting"
require "backup_location_site_setting"
require "category_search_priority_weights_validator"
require "slug_setting"
require "digest_email_site_setting"
require "email_level_site_setting"
require "mailing_list_mode_site_setting"
require "previous_replies_site_setting"
require "new_topic_duration_site_setting"
require "auto_track_duration_site_setting"
require "notification_level_when_replying_site_setting"
require "like_notification_frequency_site_setting"
require "remove_muted_tags_from_latest_site_setting"
require "site_setting"
require "site_settings/db_provider"
require "site"

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
    extra_headers = {
      "Access-Control-Allow-Origin" => Discourse.base_url_no_prefix,
      "Access-Control-Allow-Methods" => "GET, POST",
      "Access-Control-Allow-Headers" => "X-SILENCE-LOGGER, X-Shared-Session-Key, Dont-Chunk, Discourse-Present"
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

    raise Discourse::InvalidAccess if !user_id && SiteSetting.login_required

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

if Rails.env == "test"
  MessageBus.configure(backend: :memory)
else
  MessageBus.redis_config = GlobalSetting.message_bus_redis_config
end
MessageBus.reliable_pub_sub.max_backlog_size = GlobalSetting.message_bus_max_backlog_size

MessageBus.long_polling_enabled = SiteSetting.enable_long_polling
MessageBus.long_polling_interval = SiteSetting.long_polling_interval
MessageBus.cache_assets = !Rails.env.development?
MessageBus.enable_diagnostics

if Rails.env == "test" || $0 =~ /rake$/
  # disable keepalive in testing
  MessageBus.keepalive_interval = -1
end
