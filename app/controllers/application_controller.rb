# frozen_string_literal: true

require "current_user"

class ApplicationController < ActionController::Base
  include CurrentUser
  include CanonicalURL::ControllerExtensions
  include JsonError
  include GlobalPath
  include Hijack
  include ReadOnlyMixin
  include ThemeResolver
  include VaryHeader

  attr_reader :theme_id

  serialization_scope :guardian

  protect_from_forgery

  # Default Rails 3.2 lets the request through with a blank session
  #  we are being more pedantic here and nulling session / current_user
  #  and then raising a CSRF exception
  def handle_unverified_request
    # NOTE: API key is secret, having it invalidates the need for a CSRF token
    unless is_api? || is_user_api?
      super
      clear_current_user
      render plain: "[\"BAD CSRF\"]", status: 403
    end
  end

  before_action :check_readonly_mode
  before_action :handle_theme
  before_action :set_current_user_for_logs
  before_action :set_mp_snapshot_fields
  before_action :clear_notifications
  around_action :with_resolved_locale
  before_action :set_mobile_view
  before_action :block_if_readonly_mode
  before_action :authorize_mini_profiler
  before_action :redirect_to_login_if_required
  before_action :block_if_requires_login
  before_action :redirect_to_profile_if_required
  before_action :preload_json
  before_action :check_xhr
  after_action :add_readonly_header
  after_action :perform_refresh_session
  after_action :dont_cache_page
  after_action :conditionally_allow_site_embedding
  after_action :ensure_vary_header
  after_action :add_noindex_header,
               if: -> { is_feed_request? || !SiteSetting.allow_index_in_robots_txt }
  after_action :add_noindex_header_to_non_canonical, if: :spa_boot_request?
  after_action :set_cross_origin_opener_policy_header, if: :spa_boot_request?
  after_action :clean_xml, if: :is_feed_response?
  after_action :add_early_hint_header, if: -> { spa_boot_request? }

  HONEYPOT_KEY = "HONEYPOT_KEY"
  CHALLENGE_KEY = "CHALLENGE_KEY"

  layout :set_layout

  def has_escaped_fragment?
    SiteSetting.enable_escaped_fragments? && params.key?("_escaped_fragment_")
  end

  def show_browser_update?
    @show_browser_update ||= CrawlerDetection.show_browser_update?(request.user_agent)
  end
  helper_method :show_browser_update?

  def use_crawler_layout?
    @use_crawler_layout ||=
      request.user_agent && (request.media_type.blank? || request.media_type.include?("html")) &&
        !%w[json rss].include?(params[:format]) &&
        (
          has_escaped_fragment? || params.key?("print") || show_browser_update? ||
            CrawlerDetection.crawler?(request.user_agent, request.headers["HTTP_VIA"])
        )
  end

  def perform_refresh_session
    refresh_session(current_user) unless @readonly_mode
  end

  def immutable_for(duration)
    response.cache_control[:max_age] = duration.to_i
    response.cache_control[:public] = true
    response.cache_control[:extras] = ["immutable"]
  end

  def dont_cache_page
    if !response.headers["Cache-Control"] && response.cache_control.blank?
      response.cache_control[:no_cache] = true
      response.cache_control[:extras] = ["no-store"]
    end
    response.headers["Discourse-No-Onebox"] = "1" if SiteSetting.login_required
  end

  def conditionally_allow_site_embedding
    response.headers.delete("X-Frame-Options") if SiteSetting.allow_embedding_site_in_an_iframe
  end

  def ember_cli_required?
    Rails.env.development? && ENV["ALLOW_EMBER_CLI_PROXY_BYPASS"] != "1" &&
      request.headers["X-Discourse-Ember-CLI"] != "true"
  end

  def application_layout
    ember_cli_required? ? "ember_cli" : "application"
  end

  def set_layout
    case request.headers["Discourse-Render"]
    when "desktop"
      return application_layout
    when "crawler"
      return "crawler"
    end

    use_crawler_layout? ? "crawler" : application_layout
  end

  class RenderEmpty < StandardError
  end

  class PluginDisabled < StandardError
  end

  rescue_from RenderEmpty do
    with_resolved_locale { render "default/empty" }
  end

  rescue_from ArgumentError do |e|
    if e.message == "string contains null byte"
      raise Discourse::InvalidParameters, e.message
    else
      raise e
    end
  end

  rescue_from PG::ReadOnlySqlTransaction do |e|
    Discourse.received_postgres_readonly!
    Rails.logger.error("#{e.class} #{e.message}: #{e.backtrace.join("\n")}")
    rescue_with_handler(Discourse::ReadOnly.new) || raise
  end

  rescue_from ActionController::ParameterMissing do |e|
    render_json_error e.message, status: 400
  end

  rescue_from Discourse::SiteSettingMissing do |e|
    render_json_error I18n.t("site_setting_missing", name: e.message), status: 500
  end

  rescue_from ActionController::RoutingError, PluginDisabled do
    rescue_discourse_actions(:not_found, 404)
  end

  # Handles requests for giant IDs that throw pg exceptions
  rescue_from ActiveModel::RangeError do |e|
    if e.message =~ /ActiveModel::Type::Integer/
      rescue_discourse_actions(:not_found, 404)
    else
      raise e
    end
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    if request.format && request.format.json?
      render_json_error e, type: :record_invalid, status: 422
    else
      raise e
    end
  end

  rescue_from ActiveRecord::StatementInvalid do |e|
    Discourse.reset_active_record_cache_if_needed(e)
    raise e
  end

  # If they hit the rate limiter
  rescue_from RateLimiter::LimitExceeded do |e|
    retry_time_in_seconds = e&.available_in

    response_headers = { "Retry-After": retry_time_in_seconds.to_s }

    response_headers["Discourse-Rate-Limit-Error-Code"] = e.error_code if e&.error_code

    with_resolved_locale do
      render_json_error(
        e.description,
        type: :rate_limit,
        status: 429,
        extras: {
          wait_seconds: retry_time_in_seconds,
          time_left: e&.time_left,
        },
        headers: response_headers,
      )
    end
  end

  rescue_from Discourse::NotLoggedIn do |e|
    if (request.format && request.format.json?) || request.xhr? || !request.get?
      rescue_discourse_actions(:not_logged_in, 403, include_ember: true)
    else
      rescue_discourse_actions(:not_found, 404)
    end
  end

  rescue_from Discourse::InvalidParameters do |e|
    opts = { custom_message: "invalid_params", custom_message_params: { message: e.message } }

    if (request.format && request.format.json?) || request.xhr? || !request.get?
      rescue_discourse_actions(:invalid_parameters, 400, opts.merge(include_ember: true))
    else
      rescue_discourse_actions(:not_found, 400, opts)
    end
  end

  rescue_from Discourse::NotFound do |e|
    rescue_discourse_actions(
      :not_found,
      e.status,
      check_permalinks: e.check_permalinks,
      original_path: e.original_path,
      custom_message: e.custom_message,
    )
  end

  rescue_from Discourse::InvalidAccess do |e|
    cookies.delete(e.opts[:delete_cookie]) if e.opts[:delete_cookie].present?

    rescue_discourse_actions(
      :invalid_access,
      403,
      include_ember: true,
      custom_message: e.custom_message,
      custom_message_params: e.custom_message_params,
      group: e.group,
    )
  end

  rescue_from Discourse::ReadOnly do
    unless response_body
      respond_to do |format|
        format.json do
          render_json_error I18n.t("read_only_mode_enabled"), type: :read_only, status: 503
        end
        format.html { render status: 503, layout: "no_ember", template: "exceptions/read_only" }
      end
    end
  end

  rescue_from SecondFactor::AuthManager::SecondFactorRequired do |e|
    if request.xhr?
      render json: { second_factor_challenge_nonce: e.nonce }, status: 403
    else
      redirect_to session_2fa_path(nonce: e.nonce)
    end
  end

  rescue_from SecondFactor::BadChallenge do |e|
    render json: { error: I18n.t(e.error_translation_key) }, status: e.status_code
  end

  def redirect_with_client_support(url, options = {})
    if request.xhr?
      response.headers["Discourse-Xhr-Redirect"] = "true"
      render plain: url
    else
      redirect_to url, options
    end
  end

  def rescue_discourse_actions(type, status_code, opts = nil)
    opts ||= {}
    show_json_errors =
      (request.format && request.format.json?) || (request.xhr?) ||
        ((params[:external_id] || "").ends_with? ".json")

    if type == :not_found && opts[:check_permalinks]
      url = opts[:original_path] || request.fullpath
      permalink = Permalink.find_by_url(url)

      # there are some cases where we have a permalink but no url
      # cause category / topic was deleted
      if permalink.present? && permalink.target_url
        # permalink present, redirect to that URL
        redirect_with_client_support permalink.target_url,
                                     status: :moved_permanently,
                                     allow_other_host: true
        return
      end
    end

    message = title = nil
    with_resolved_locale(check_current_user: false) do
      if opts[:custom_message]
        title = message = I18n.t(opts[:custom_message], opts[:custom_message_params] || {})
      else
        message = I18n.t(type)
        if status_code == 403
          title = I18n.t("page_forbidden.title")
        else
          title = I18n.t("page_not_found.title")
        end
      end
    end

    error_page_opts = { title: title, status: status_code, group: opts[:group] }

    if show_json_errors
      opts = { type: type, status: status_code }

      with_resolved_locale(check_current_user: false) do
        # Include error in HTML format for topics#show.
        if (request.params[:controller] == "topics" && request.params[:action] == "show") ||
             (
               request.params[:controller] == "categories" &&
                 request.params[:action] == "find_by_slug"
             )
          opts[:extras] = {
            title: I18n.t("page_not_found.page_title"),
            html: build_not_found_page(error_page_opts),
            group: error_page_opts[:group],
          }
        end
      end

      render_json_error message, opts
    else
      begin
        # 404 pages won't have the session and theme_keys without these:
        current_user
        handle_theme
      rescue Discourse::InvalidAccess
        return render plain: message, status: status_code
      end
      with_resolved_locale do
        error_page_opts[:layout] = (opts[:include_ember] && @preloaded) ? set_layout : "no_ember"
        render html: build_not_found_page(error_page_opts)
      end
    end
  end

  # If a controller requires a plugin, it will raise an exception if that plugin is
  # disabled. This allows plugins to be disabled programmatically.
  def self.requires_plugin(plugin_name)
    before_action do
      if plugin = Discourse.plugins_by_name[plugin_name]
        raise PluginDisabled.new if !plugin.enabled?
      elsif Rails.env.test?
        raise "Required plugin '#{plugin_name}' not found. The string passed to requires_plugin should match the plugin's name at the top of plugin.rb"
      else
        Rails.logger.warn("Required plugin '#{plugin_name}' not found")
      end
    end
  end

  def set_current_user_for_logs
    if current_user
      Logster.add_to_env(request.env, "username", current_user.username)
      response.headers["X-Discourse-Username"] = current_user.username
    end
    response.headers["X-Discourse-Route"] = "#{controller_path.gsub("/", "::")}/#{action_name}"
  end

  def set_mp_snapshot_fields
    if defined?(Rack::MiniProfiler)
      Rack::MiniProfiler.add_snapshot_custom_field("Application version", Discourse.git_version)
      if Rack::MiniProfiler.snapshots_transporter?
        Rack::MiniProfiler.add_snapshot_custom_field("Site", Discourse.current_hostname)
      end
    end
  end

  def clear_notifications
    if current_user && !@readonly_mode
      cookie_notifications = cookies["cn"]
      notifications = request.headers["Discourse-Clear-Notifications"]

      if cookie_notifications
        if notifications.present?
          notifications += ",#{cookie_notifications}"
        else
          notifications = cookie_notifications
        end
      end

      if notifications.present?
        notification_ids = notifications.split(",").map(&:to_i)
        Notification.read(current_user, notification_ids)
        current_user.reload
        current_user.publish_notifications_state
        cookie_args = {}
        cookie_args[:path] = Discourse.base_path if Discourse.base_path.present?
        cookies.delete("cn", cookie_args)
      end
    end
  end

  def with_resolved_locale(check_current_user: true)
    if check_current_user &&
         (
           user =
             begin
               current_user
             rescue StandardError
               nil
             end
         )
      locale = user.effective_locale
    else
      locale = Discourse.anonymous_locale(request)
      locale ||= SiteSetting.default_locale
    end

    locale = SiteSettings::DefaultsProvider::DEFAULT_LOCALE if !I18n.locale_available?(locale)

    I18n.ensure_all_loaded!
    I18n.with_locale(locale) { yield }
  end

  def store_preloaded(key, json)
    @preloaded ||= {}
    # I dislike that there is a gsub as opposed to a gsub!
    #  but we can not be mucking with user input, I wonder if there is a way
    #  to inject this safety deeper in the library or even in AM serializer
    @preloaded[key] = json.gsub("</", "<\\/")
  end

  # If we are rendering HTML, preload the session data
  def preload_json
    # We don't preload JSON on xhr or JSON request
    return if request.xhr? || request.format.json?

    # if we are posting in makes no sense to preload
    return if request.method != "GET"

    # TODO should not be invoked on redirection so this should be further deferred
    preload_anonymous_data

    if current_user
      current_user.sync_notification_channel_position
      preload_current_user_data
    end
  end

  def set_mobile_view
    session[:mobile_view] = params[:mobile_view] if params.has_key?(:mobile_view)
  end

  NO_THEMES = "no_themes"
  NO_PLUGINS = "no_plugins"
  NO_UNOFFICIAL_PLUGINS = "no_unofficial_plugins"
  SAFE_MODE = "safe_mode"

  LEGACY_NO_THEMES = "no_custom"
  LEGACY_NO_UNOFFICIAL_PLUGINS = "only_official"

  def resolve_safe_mode
    return unless guardian.can_enable_safe_mode?

    safe_mode = params[SAFE_MODE]
    if safe_mode.is_a?(String)
      safe_mode = safe_mode.split(",")
      request.env[NO_THEMES] = safe_mode.include?(NO_THEMES) || safe_mode.include?(LEGACY_NO_THEMES)
      request.env[NO_PLUGINS] = safe_mode.include?(NO_PLUGINS)
      request.env[NO_UNOFFICIAL_PLUGINS] = safe_mode.include?(NO_UNOFFICIAL_PLUGINS) ||
        safe_mode.include?(LEGACY_NO_UNOFFICIAL_PLUGINS)
    end
  end

  def handle_theme
    return if request.format == "js"

    resolve_safe_mode
    return if request.env[NO_THEMES]

    @theme_id ||= ThemeResolver.resolve_theme_id(request, guardian, current_user)
  end

  def guardian
    # sometimes we log on a user in the middle of a request so we should throw
    # away the cached guardian instance when we do that
    if (@guardian&.user).blank? && current_user.present?
      @guardian = Guardian.new(current_user, request)
    end
    @guardian ||= Guardian.new(current_user, request)
  end

  def current_homepage
    current_user&.user_option&.homepage || HomepageHelper.resolve(request, current_user)
  end

  def serialize_data(obj, serializer, opts = nil)
    # If it's an array, apply the serializer as an each_serializer to the elements
    serializer_opts = { scope: guardian }.merge!(opts || {})
    if obj.respond_to?(:to_ary)
      serializer_opts[:each_serializer] = serializer
      ActiveModel::ArraySerializer.new(obj.to_ary, serializer_opts).as_json
    else
      serializer.new(obj, serializer_opts).as_json
    end
  end

  # This is odd, but it seems that in Rails `render json: obj` is about
  # 20% slower than calling MultiJSON.dump ourselves. I'm not sure why
  # Rails doesn't call MultiJson.dump when you pass it json: obj but
  # it seems we don't need whatever Rails is doing.
  def render_serialized(obj, serializer, opts = nil)
    render_json_dump(serialize_data(obj, serializer, opts), opts)
  end

  def render_json_dump(obj, opts = nil)
    opts ||= {}
    if opts[:rest_serializer]
      obj["__rest_serializer"] = "1"
      opts.each { |k, v| obj[k] = v if k.to_s.start_with?("refresh_") }

      obj["extras"] = opts[:extras] if opts[:extras]
      obj["meta"] = opts[:meta] if opts[:meta]
    end

    render json: MultiJson.dump(obj), status: opts[:status] || 200
  end

  def can_cache_content?
    current_user.blank? && cookies[:authentication_data].blank?
  end

  # Our custom cache method
  def discourse_expires_in(time_length)
    return unless can_cache_content?
    Middleware::AnonymousCache.anon_cache(request.env, time_length)
  end

  def fetch_user_from_params(opts = nil, eager_load = [])
    opts ||= {}
    user =
      if params[:username]
        username_lower = params[:username].downcase.chomp(".json")

        if current_user && current_user.username_lower == username_lower
          current_user
        else
          find_opts = { username_lower: username_lower }
          find_opts[:active] = true unless opts[:include_inactive] || current_user.try(:staff?)
          result = User
          (result = result.includes(*eager_load)) if !eager_load.empty?
          result.find_by(find_opts)
        end
      elsif params[:external_id]
        external_id = params[:external_id].chomp(".json")
        if provider_name = params[:external_provider]
          raise Discourse::InvalidAccess unless guardian.is_admin? # external_id might be something sensitive
          provider = Discourse.enabled_authenticators.find { |a| a.name == provider_name }
          raise Discourse::NotFound if !provider&.is_managed? # Only managed authenticators use UserAssociatedAccount
          UserAssociatedAccount.find_by(
            provider_name: provider_name,
            provider_uid: external_id,
          )&.user
        else
          SingleSignOnRecord.find_by(external_id: external_id).try(:user)
        end
      end
    raise Discourse::NotFound if user.blank?

    guardian.ensure_can_see!(user)
    user
  end

  def post_ids_including_replies
    post_ids = params[:post_ids].map(&:to_i)
    post_ids |= PostReply.where(post_id: params[:reply_post_ids]).pluck(:reply_post_id) if params[
      :reply_post_ids
    ]
    post_ids
  end

  def no_cookies
    # do your best to ensure response has no cookies
    # longer term we may want to push this into middleware
    headers.delete "Set-Cookie"
    request.session_options[:skip] = true
  end

  def secure_session
    SecureSession.new(session["secure_session_id"] ||= SecureRandom.hex)
  end

  def handle_permalink(path)
    permalink = Permalink.find_by_url(path)
    if permalink && permalink.target_url
      redirect_to permalink.target_url, status: :moved_permanently
    end
  end

  def rate_limit_second_factor!(user)
    return if params[:second_factor_token].blank?

    RateLimiter.new(nil, "second-factor-min-#{request.remote_ip}", 6, 1.minute).performed!

    RateLimiter.new(nil, "second-factor-min-#{user.username}", 6, 1.minute).performed! if user
  end

  def login_method
    return if current_user.anonymous?
    current_user.authenticated_with_oauth ? Auth::LOGIN_METHOD_OAUTH : Auth::LOGIN_METHOD_LOCAL
  end

  private

  def preload_anonymous_data
    store_preloaded("site", Site.json_for(guardian))
    store_preloaded("siteSettings", SiteSetting.client_settings_json)
    store_preloaded("customHTML", custom_html_json)
    store_preloaded("banner", banner_json)
    store_preloaded("customEmoji", custom_emoji)
    store_preloaded("isReadOnly", get_or_check_readonly_mode.to_json)
    store_preloaded("isStaffWritesOnly", get_or_check_staff_writes_only_mode.to_json)
    store_preloaded("activatedThemes", activated_themes_json)
  end

  def preload_current_user_data
    store_preloaded(
      "currentUser",
      MultiJson.dump(
        CurrentUserSerializer.new(
          current_user,
          scope: guardian,
          root: false,
          login_method: login_method,
        ),
      ),
    )

    report = TopicTrackingState.report(current_user)
    serializer = TopicTrackingStateSerializer.new(report, scope: guardian, root: false)

    hash = serializer.as_json

    store_preloaded("topicTrackingStates", MultiJson.dump(hash[:data]))
    store_preloaded("topicTrackingStateMeta", MultiJson.dump(hash[:meta]))

    if current_user.admin?
      # This is used in the wizard so we can preload fonts using the FontMap JS API.
      store_preloaded("fontMap", MultiJson.dump(load_font_map))

      # Used to show plugin-specific admin routes in the sidebar.
      store_preloaded(
        "visiblePlugins",
        MultiJson.dump(
          Discourse
            .plugins_sorted_by_name(enabled_only: false)
            .map do |plugin|
              {
                name: plugin.name.downcase,
                admin_route: plugin.full_admin_route,
                enabled: plugin.enabled?,
              }
            end,
        ),
      )
    end
  end

  def custom_html_json
    target = view_context.mobile_view? ? :mobile : :desktop

    data =
      if @theme_id.present?
        {
          top: Theme.lookup_field(@theme_id, target, "after_header"),
          footer: Theme.lookup_field(@theme_id, target, "footer"),
        }
      else
        {}
      end

    data.merge! DiscoursePluginRegistry.custom_html if DiscoursePluginRegistry.custom_html

    DiscoursePluginRegistry.html_builders.each do |name, _|
      if name.start_with?("client:")
        data[name.sub(/\Aclient:/, "")] = DiscoursePluginRegistry.build_html(name, self)
      end
    end

    MultiJson.dump(data)
  end

  def self.banner_json_cache
    @banner_json_cache ||= DistributedCache.new("banner_json")
  end

  def banner_json
    return "{}" if !current_user && SiteSetting.login_required?

    ApplicationController
      .banner_json_cache
      .defer_get_set("json") do
        topic = Topic.where(archetype: Archetype.banner).first
        banner = topic.present? ? topic.banner : {}
        MultiJson.dump(banner)
      end
  end

  def custom_emoji
    serializer = ActiveModel::ArraySerializer.new(Emoji.custom, each_serializer: EmojiSerializer)
    MultiJson.dump(serializer)
  end

  # Render action for a JSON error.
  #
  # obj       - a translated string, an ActiveRecord model, or an array of translated strings
  # opts:
  #   type    - a machine-readable description of the error
  #   status  - HTTP status code to return
  #   headers - extra headers for the response
  def render_json_error(obj, opts = {})
    opts = { status: opts } if opts.is_a?(Integer)
    opts.fetch(:headers, {}).each { |name, value| headers[name.to_s] = value }

    render(
      json: MultiJson.dump(create_errors_json(obj, opts)),
      status: opts[:status] || status_code(obj),
    )
  end

  def status_code(obj)
    return 403 if obj.try(:forbidden)
    return 404 if obj.try(:not_found)
    422
  end

  def success_json
    { success: "OK" }
  end

  def failed_json
    { failed: "FAILED" }
  end

  def json_result(obj, opts = {})
    if yield(obj)
      json = success_json

      # If we were given a serializer, add the class to the json that comes back
      if opts[:serializer].present?
        json[obj.class.name.underscore] = opts[:serializer].new(
          obj,
          scope: guardian,
        ).serializable_hash
      end

      render json: MultiJson.dump(json)
    else
      error_obj = nil
      if opts[:additional_errors]
        error_target =
          opts[:additional_errors].find do |o|
            target = obj.public_send(o)
            target && target.errors.present?
          end
        error_obj = obj.public_send(error_target) if error_target
      end
      render_json_error(error_obj || obj)
    end
  end

  def mini_profiler_enabled?
    defined?(Rack::MiniProfiler) && (guardian.is_developer? || Rails.env.development?)
  end

  def authorize_mini_profiler
    return unless mini_profiler_enabled?
    Rack::MiniProfiler.authorize_request
  end

  def check_xhr
    # bypass xhr check on PUT / POST / DELETE provided api key is there, otherwise calling api is annoying
    return if !request.get? && (is_api? || is_user_api?)
    raise ApplicationController::RenderEmpty.new if !request.format&.json? && !request.xhr?
  end

  def apply_cdn_headers
    if Discourse.is_cdn_request?(request.env, request.method)
      Discourse.apply_cdn_headers(response.headers)
    end
  end

  def self.requires_login(arg = {})
    @requires_login_arg = arg
  end

  def self.requires_login_arg
    @requires_login_arg
  end

  def block_if_requires_login
    if arg = self.class.requires_login_arg
      check =
        if except = arg[:except]
          !except.include?(action_name.to_sym)
        elsif only = arg[:only]
          only.include?(action_name.to_sym)
        else
          true
        end
      ensure_logged_in if check
    end
  end

  def ensure_logged_in
    raise Discourse::NotLoggedIn.new if current_user.blank?
  end

  def ensure_staff
    raise Discourse::InvalidAccess.new unless current_user && current_user.staff?
  end

  def ensure_admin
    raise Discourse::InvalidAccess.new unless current_user && current_user.admin?
  end

  def ensure_wizard_enabled
    raise Discourse::InvalidAccess.new unless SiteSetting.wizard_enabled?
  end

  def destination_url
    request.original_url unless request.original_url =~ /uploads/
  end

  def redirect_to_login
    dont_cache_page

    if SiteSetting.auth_immediately && SiteSetting.enable_discourse_connect?
      # save original URL in a session so we can redirect after login
      session[:destination_url] = destination_url
      redirect_to path("/session/sso")
    elsif SiteSetting.auth_immediately && !SiteSetting.enable_local_logins &&
          Discourse.enabled_authenticators.length == 1 && !cookies[:authentication_data]
      # Only one authentication provider, direct straight to it.
      # If authentication_data is present, then we are halfway though registration. Don't redirect offsite
      cookies[:destination_url] = destination_url
      redirect_to path("/auth/#{Discourse.enabled_authenticators.first.name}")
    else
      # save original URL in a cookie (javascript redirects after login in this case)
      cookies[:destination_url] = destination_url
      redirect_to path("/login")
    end
  end

  def redirect_to_login_if_required
    return if request.format.json? && is_api?

    # Used by clients authenticated via user API.
    # Redirects to provided URL scheme if
    # - request uses a valid public key and auth_redirect scheme
    # - one_time_password scope is allowed
    if !current_user && params.has_key?(:user_api_public_key) && params.has_key?(:auth_redirect)
      begin
        OpenSSL::PKey::RSA.new(params[:user_api_public_key])
      rescue OpenSSL::PKey::RSAError
        return render plain: I18n.t("user_api_key.invalid_public_key")
      end

      if UserApiKeyClient.invalid_auth_redirect?(params[:auth_redirect])
        return render plain: I18n.t("user_api_key.invalid_auth_redirect")
      end

      if UserApiKey.allowed_scopes.superset?(Set.new(["one_time_password"]))
        redirect_to("#{params[:auth_redirect]}?otp=true", allow_other_host: true)
        return
      end
    end

    if !current_user && SiteSetting.login_required?
      flash.keep
      if (request.format && request.format.json?) || request.xhr? || !request.get?
        ensure_logged_in
      else
        redirect_to_login
      end
      return
    end

    return if !current_user
    return if !should_enforce_2fa?

    redirect_path = path("/u/#{current_user.encoded_username}/preferences/second-factor")
    if !request.fullpath.start_with?(redirect_path)
      redirect_to path(redirect_path)
      nil
    end
  end

  def should_enforce_2fa?
    enforcing_2fa =
      (
        (SiteSetting.enforce_second_factor == "staff" && current_user.staff?) ||
          SiteSetting.enforce_second_factor == "all"
      )
    !disqualified_from_2fa_enforcement && enforcing_2fa &&
      !current_user.has_any_second_factor_methods_enabled?
  end

  def disqualified_from_2fa_enforcement
    request.format.json? || is_api? || current_user.anonymous? ||
      (
        !SiteSetting.enforce_second_factor_on_external_auth &&
          login_method == Auth::LOGIN_METHOD_OAUTH
      )
  end

  def redirect_to_profile_if_required
    return if request.format.json?
    return if !current_user
    return if !current_user.needs_required_fields_check?

    if current_user.populated_required_custom_fields?
      current_user.bump_required_fields_version
      return
    end

    redirect_path = path("/u/#{current_user.encoded_username}/preferences/profile")
    second_factor_path = path("/u/#{current_user.encoded_username}/preferences/second-factor")
    allowed_paths = [redirect_path, second_factor_path, path("/admin"), path("/safe-mode")]
    if allowed_paths.none? { |p| request.fullpath.start_with?(p) }
      rate_limiter = RateLimiter.new(current_user, "redirect_to_required_fields_log", 1, 24.hours)

      if rate_limiter.performed!(raise_error: false)
        UserHistory.create!(
          action: UserHistory.actions[:redirected_to_required_fields],
          acting_user_id: current_user.id,
        )
      end

      redirect_to path(redirect_path)
      nil
    end
  end

  def build_not_found_page(opts = {})
    if SiteSetting.bootstrap_error_pages?
      preload_json
      opts[:layout] = "application" if opts[:layout] == "no_ember"
    end

    @current_user =
      begin
        current_user
      rescue StandardError
        nil
      end

    if !SiteSetting.login_required? || @current_user
      key = "page_not_found_topics:#{I18n.locale}"
      @topics_partial =
        Discourse
          .cache
          .fetch(key, expires_in: 10.minutes) do
            category_topic_ids = Category.select(:topic_id).where.not(topic_id: nil)
            @top_viewed =
              TopicQuery
                .new(nil, except_topic_ids: category_topic_ids)
                .list_top_for("monthly")
                .topics
                .first(10)
            @recent = Topic.includes(:category).where.not(id: category_topic_ids).recent(10)
            render_to_string partial: "/exceptions/not_found_topics", formats: [:html]
          end
          .html_safe
    end

    @container_class = "wrap not-found-container"
    @page_title = I18n.t("page_not_found.page_title")
    @title = opts[:title] || I18n.t("page_not_found.title")
    @group = opts[:group]
    @hide_search = true if SiteSetting.login_required

    params[:slug] = params[:slug].first if params[:slug].kind_of?(Array)
    params[:id] = params[:id].first if params[:id].kind_of?(Array)
    @slug = (params[:slug].presence || params[:id].presence || "").to_s.tr("-", " ")

    render_to_string status: opts[:status],
                     layout: opts[:layout],
                     formats: [:html],
                     template: "/exceptions/not_found"
  end

  def is_asset_path
    request.env["DISCOURSE_IS_ASSET_PATH"] = 1
  end

  def is_feed_request?
    request.format.atom? || request.format.rss?
  end

  def is_feed_response?
    request.get? && response&.content_type&.match?(/(rss|atom)/)
  end

  def add_noindex_header
    if request.get? && !response.headers["X-Robots-Tag"]
      if SiteSetting.allow_index_in_robots_txt
        response.headers["X-Robots-Tag"] = "noindex"
      else
        response.headers["X-Robots-Tag"] = "noindex, nofollow"
      end
    end
  end

  def add_noindex_header_to_non_canonical
    canonical = (@canonical_url || @default_canonical)
    if canonical.present? && canonical != request.url &&
         !SiteSetting.allow_indexing_non_canonical_urls
      response.headers["X-Robots-Tag"] ||= "noindex"
    end
  end

  def set_cross_origin_opener_policy_header
    if current_user.present? && SiteSetting.cross_origin_opener_unsafe_none_groups_map.any? &&
         current_user.in_any_groups?(SiteSetting.cross_origin_opener_unsafe_none_groups_map)
      response.headers["Cross-Origin-Opener-Policy"] = "unsafe-none"
    else
      response.headers["Cross-Origin-Opener-Policy"] = SiteSetting.cross_origin_opener_policy_header
    end
  end

  protected

  def honeypot_value
    secure_session[HONEYPOT_KEY] ||= SecureRandom.hex
  end

  def challenge_value
    secure_session[CHALLENGE_KEY] ||= SecureRandom.hex
  end

  def render_post_json(post, add_raw: true)
    post_serializer = PostSerializer.new(post, scope: guardian, root: false)
    post_serializer.add_raw = add_raw

    counts = PostAction.counts_for([post], current_user)
    if counts && counts = counts[post.id]
      post_serializer.post_actions = counts
    end
    render_json_dump(post_serializer)
  end

  # returns an array of integers given a param key
  # returns nil if key is not found
  def param_to_integer_list(key, delimiter = ",")
    case params[key]
    when String
      params[key].split(delimiter).map(&:to_i)
    when Array
      params[key].map(&:to_i)
    end
  end

  def activated_themes_json
    id = @theme_id
    return "{}" if id.blank?
    ids = Theme.transform_ids(id)
    Theme.where(id: ids).pluck(:id, :name).to_h.to_json
  end

  def run_second_factor!(action_class, action_data: nil, target_user: current_user)
    if current_user && target_user != current_user
      # Anon can run 2fa against another target, but logged-in users should not.
      # This should be validated at the `run_second_factor!` call site.
      raise "running 2fa against another user is not allowed"
    end

    action = action_class.new(guardian, request, opts: action_data, target_user: target_user)
    manager = SecondFactor::AuthManager.new(guardian, action, target_user: target_user)
    yield(manager) if block_given?
    result = manager.run!(request, params, secure_session)

    if !result.no_second_factors_enabled? && !result.second_factor_auth_completed? &&
         !result.second_factor_auth_skipped?
      # should never happen, but I want to know if somehow it does! (osama)
      raise "2fa process ended up in a bad state!"
    end

    result
  end

  # We don't actually send 103 Early Hint responses from Discourse. However, upstream proxies can be configured
  # to cache a response header from the app and use that to send an Early Hint response to future clients.
  # See 'early_hint_header_mode' and 'early_hint_header_name' Global Setting descriptions for more info.
  def add_early_hint_header
    return if GlobalSetting.early_hint_header_mode.nil?

    links = []

    if GlobalSetting.early_hint_header_mode == "preconnect"
      [GlobalSetting.cdn_url, SiteSetting.s3_cdn_url].each do |url|
        next if url.blank?
        base_url = URI.join(url, "/").to_s.chomp("/")
        links.push("<#{base_url}>; rel=preconnect")
      end
    elsif GlobalSetting.early_hint_header_mode == "preload"
      links.push(*@asset_preload_links)
    end

    response.headers[GlobalSetting.early_hint_header_name] = links.join(", ") if links.present?
  end

  def spa_boot_request?
    request.get? && !(request.format && request.format.json?) && !request.xhr?
  end

  def load_font_map
    DiscourseFonts
      .fonts
      .each_with_object({}) do |font, font_map|
        next if !font[:variants]
        font_map[font[:key]] = font[:variants].map do |v|
          {
            url: "#{Discourse.base_url}/fonts/#{v[:filename]}?v=#{DiscourseFonts::VERSION}",
            weight: v[:weight],
          }
        end
      end
  end

  def fetch_limit_from_params(params: self.params, default:, max:)
    fetch_int_from_params(:limit, params: params, default: default, max: max)
  end

  def fetch_int_from_params(key, params: self.params, default:, min: 0, max: nil)
    key = key.to_sym

    if default.present? && ((max.present? && default > max) || (min.present? && default < min))
      raise "default #{key.inspect} is not between #{min.inspect} and #{max.inspect}"
    end

    if params.has_key?(key)
      value =
        begin
          Integer(params[key])
        rescue ArgumentError
          raise Discourse::InvalidParameters.new(key)
        end

      if (min.present? && value < min) || (max.present? && value > max)
        raise Discourse::InvalidParameters.new(key)
      end

      value
    else
      default
    end
  end

  def clean_xml
    response.body.gsub!(XmlCleaner::INVALID_CHARACTERS, "")
  end

  def service_params
    { params: params.to_unsafe_h, guardian: }
  end
end
