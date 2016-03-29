require 'current_user'
require_dependency 'canonical_url'
require_dependency 'discourse'
require_dependency 'custom_renderer'
require_dependency 'archetype'
require_dependency 'rate_limiter'
require_dependency 'crawler_detection'
require_dependency 'json_error'
require_dependency 'letter_avatar'
require_dependency 'distributed_cache'
require_dependency 'global_path'

class ApplicationController < ActionController::Base
  include CurrentUser
  include CanonicalURL::ControllerExtensions
  include JsonError
  include GlobalPath

  serialization_scope :guardian

  protect_from_forgery

  # Default Rails 3.2 lets the request through with a blank session
  #  we are being more pedantic here and nulling session / current_user
  #  and then raising a CSRF exception
  def handle_unverified_request
    # NOTE: API key is secret, having it invalidates the need for a CSRF token
    unless is_api?
      super
      clear_current_user
      render text: "['BAD CSRF']", status: 403
    end
  end

  before_filter :set_current_user_for_logs
  before_filter :clear_notifications
  before_filter :set_locale
  before_filter :set_mobile_view
  before_filter :inject_preview_style
  before_filter :disable_customization
  before_filter :block_if_readonly_mode
  before_filter :authorize_mini_profiler
  before_filter :preload_json
  before_filter :redirect_to_login_if_required
  before_filter :check_xhr
  after_filter  :add_readonly_header

  layout :set_layout

  def has_escaped_fragment?
    SiteSetting.enable_escaped_fragments? && params.key?("_escaped_fragment_")
  end

  def use_crawler_layout?
    @use_crawler_layout ||= (has_escaped_fragment? || CrawlerDetection.crawler?(request.user_agent))
  end

  def add_readonly_header
    response.headers['Discourse-Readonly'] = 'true' if Discourse.readonly_mode?
  end

  def slow_platform?
    request.user_agent =~ /Android/
  end

  def set_layout
    use_crawler_layout? ? 'crawler' : 'application'
  end

  # Some exceptions
  class RenderEmpty < StandardError; end

  # Render nothing
  rescue_from RenderEmpty do
    render 'default/empty'
  end

  def render_rate_limit_error(e)
    render_json_error e.description, type: :rate_limit, status: 429
  end

  # If they hit the rate limiter
  rescue_from RateLimiter::LimitExceeded do |e|
    render_rate_limit_error(e)
  end

  rescue_from PG::ReadOnlySqlTransaction do |e|
    Discourse.received_readonly!
    raise Discourse::ReadOnly
  end

  rescue_from Discourse::NotLoggedIn do |e|
    raise e if Rails.env.test?
    if (request.format && request.format.json?) || request.xhr? || !request.get?
      rescue_discourse_actions(:not_logged_in, 403, true)
    else
      rescue_discourse_actions(:not_found, 404)
    end
  end

  class PluginDisabled < StandardError; end

  # Handles requests for giant IDs that throw pg exceptions
  rescue_from RangeError do |e|
    if e.message =~ /ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Integer/
      rescue_discourse_actions(:not_found, 404)
    else
      raise e
    end
  end

  rescue_from Discourse::NotFound, PluginDisabled  do
    rescue_discourse_actions(:not_found, 404)
  end

  rescue_from Discourse::InvalidAccess do
    rescue_discourse_actions(:invalid_access, 403, true)
  end

  rescue_from Discourse::ReadOnly do
    render_json_error I18n.t('read_only_mode_enabled'), type: :read_only, status: 405
  end

  def rescue_discourse_actions(type, status_code, include_ember=false)

    if (request.format && request.format.json?) || (request.xhr?)
      # HACK: do not use render_json_error for topics#show
      if request.params[:controller] == 'topics' && request.params[:action] == 'show'
        return render status: status_code, layout: false, text: (status_code == 404 || status_code == 410) ? build_not_found_page(status_code) : I18n.t(type)
      end

      render_json_error I18n.t(type), type: type, status: status_code
    else
      render text: build_not_found_page(status_code, include_ember ? 'application' : 'no_ember')
    end
  end

  # If a controller requires a plugin, it will raise an exception if that plugin is
  # disabled. This allows plugins to be disabled programatically.
  def self.requires_plugin(plugin_name)
    before_filter do
      raise PluginDisabled.new if Discourse.disabled_plugin_names.include?(plugin_name)
    end
  end

  def set_current_user_for_logs
    if current_user
      Logster.add_to_env(request.env,"username",current_user.username)
      response.headers["X-Discourse-Username"] = current_user.username
    end
    response.headers["X-Discourse-Route"] = "#{controller_name}/#{action_name}"
  end

  def clear_notifications
    if current_user && !Discourse.readonly_mode?

      cookie_notifications = cookies['cn'.freeze]
      notifications = request.headers['Discourse-Clear-Notifications'.freeze]

      if cookie_notifications
        if notifications.present?
          notifications += "," << cookie_notifications
        else
          notifications = cookie_notifications
        end
      end

      if notifications.present?
        notification_ids = notifications.split(",").map(&:to_i)
        count = Notification.where(user_id: current_user.id, id: notification_ids, read: false).update_all(read: true)
        if count > 0
          current_user.publish_notifications_state
        end
        cookies.delete('cn')
      end
    end
  end

  def set_locale
    if !current_user
      if SiteSetting.set_locale_from_accept_language_header
        I18n.locale = locale_from_header
      else
        I18n.locale = SiteSetting.default_locale
      end
    else
      I18n.locale = current_user.effective_locale
    end
    I18n.ensure_all_loaded!
  end

  def store_preloaded(key, json)
    @preloaded ||= {}
    # I dislike that there is a gsub as opposed to a gsub!
    #  but we can not be mucking with user input, I wonder if there is a way
    #  to inject this safty deeper in the library or even in AM serializer
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
      preload_current_user_data
      current_user.sync_notification_channel_position
    end
  end

  def set_mobile_view
    session[:mobile_view] = params[:mobile_view] if params.has_key?(:mobile_view)
  end

  def inject_preview_style
    style = request['preview-style']

    if style.nil?
      session[:preview_style] = cookies[:preview_style]
    else
      cookies.delete(:preview_style)

      if style.blank? || style == 'default'
        session[:preview_style] = nil
      else
        session[:preview_style] = style
        if request['sticky']
          cookies[:preview_style] = style
        end
      end
    end

  end

  def disable_customization
    session[:disable_customization] = params[:customization] == "0" if params.has_key?(:customization)
  end

  def guardian
    @guardian ||= Guardian.new(current_user)
  end

  def current_homepage
    current_user ? SiteSetting.homepage : SiteSetting.anonymous_homepage
  end

  def serialize_data(obj, serializer, opts=nil)
    # If it's an array, apply the serializer as an each_serializer to the elements
    serializer_opts = {scope: guardian}.merge!(opts || {})
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
  def render_serialized(obj, serializer, opts=nil)
    render_json_dump(serialize_data(obj, serializer, opts), opts)
  end

  def render_json_dump(obj, opts=nil)
    opts ||= {}
    if opts[:rest_serializer]
      obj['__rest_serializer'] = "1"
      opts.each do |k, v|
        obj[k] = v if k.to_s.start_with?("refresh_")
      end

      obj['extras'] = opts[:extras] if opts[:extras]
    end

    render json: MultiJson.dump(obj), status: opts[:status] || 200
  end

  def can_cache_content?
    current_user.blank? && flash[:authentication_data].blank?
  end

  # Our custom cache method
  def discourse_expires_in(time_length)
    return unless can_cache_content?
    Middleware::AnonymousCache.anon_cache(request.env, time_length)
  end

  def fetch_user_from_params(opts=nil)
    opts ||= {}
    user = if params[:username]
      username_lower = params[:username].downcase
      username_lower.gsub!(/\.json$/, '')
      find_opts = { username_lower: username_lower }
      find_opts[:active] = true unless opts[:include_inactive] || current_user.try(:staff?)
      User.find_by(find_opts)
    elsif params[:external_id]
      external_id = params[:external_id].gsub(/\.json$/, '')
      SingleSignOnRecord.find_by(external_id: external_id).try(:user)
    end
    raise Discourse::NotFound if user.blank?

    guardian.ensure_can_see!(user)
    user
  end

  def post_ids_including_replies
    post_ids = params[:post_ids].map {|p| p.to_i}
    if params[:reply_post_ids]
      post_ids << PostReply.where(post_id: params[:reply_post_ids].map {|p| p.to_i}).pluck(:reply_id)
      post_ids.flatten!
      post_ids.uniq!
    end
    post_ids
  end

  def no_cookies
    # do your best to ensure response has no cookies
    # longer term we may want to push this into middleware
    headers.delete 'Set-Cookie'
    request.session_options[:skip] = true
  end

  private

    def locale_from_header
      begin
        # Rails I18n uses underscores between the locale and the region; the request
        # headers use hyphens.
        require 'http_accept_language' unless defined? HttpAcceptLanguage
        available_locales = I18n.available_locales.map { |locale| locale.to_s.gsub(/_/, '-') }
        parser = HttpAcceptLanguage::Parser.new(request.env["HTTP_ACCEPT_LANGUAGE"])
        parser.language_region_compatible_from(available_locales).gsub(/-/, '_')
      rescue
        # If Accept-Language headers are not set.
        I18n.default_locale
      end
    end

    def preload_anonymous_data
      store_preloaded("site", Site.json_for(guardian))
      store_preloaded("siteSettings", SiteSetting.client_settings_json)
      store_preloaded("customHTML", custom_html_json)
      store_preloaded("banner", banner_json)
      store_preloaded("customEmoji", custom_emoji)
      store_preloaded("translationOverrides", I18n.client_overrides_json(I18n.locale))
    end

    def preload_current_user_data
      store_preloaded("currentUser", MultiJson.dump(CurrentUserSerializer.new(current_user, scope: guardian, root: false)))
      report = TopicTrackingState.report(current_user.id)
      serializer = ActiveModel::ArraySerializer.new(report, each_serializer: TopicTrackingStateSerializer)
      store_preloaded("topicTrackingStates", MultiJson.dump(serializer))
    end

    def custom_html_json
      target = view_context.mobile_view? ? :mobile : :desktop
      data = {
        top: SiteCustomization.custom_top(session[:preview_style], target),
        footer: SiteCustomization.custom_footer(session[:preview_style], target)
      }

      if DiscoursePluginRegistry.custom_html
        data.merge! DiscoursePluginRegistry.custom_html
      end

      MultiJson.dump(data)
    end

    def self.banner_json_cache
      @banner_json_cache ||= DistributedCache.new("banner_json")
    end

    def banner_json
      json = ApplicationController.banner_json_cache["json"]

      unless json
        topic = Topic.where(archetype: Archetype.banner).limit(1).first
        banner = topic.present? ? topic.banner : {}
        ApplicationController.banner_json_cache["json"] = json = MultiJson.dump(banner)
      end

      json
    end

    def custom_emoji
      serializer = ActiveModel::ArraySerializer.new(Emoji.custom, each_serializer: EmojiSerializer)
      MultiJson.dump(serializer)
    end

    # Render action for a JSON error.
    #
    # obj      - a translated string, an ActiveRecord model, or an array of translated strings
    # opts:
    #   type   - a machine-readable description of the error
    #   status - HTTP status code to return
    def render_json_error(obj, opts={})
      opts = { status: opts } if opts.is_a?(Fixnum)
      render json: MultiJson.dump(create_errors_json(obj, opts[:type])), status: opts[:status] || 422
    end

    def success_json
      { success: 'OK' }
    end

    def failed_json
      { failed: 'FAILED' }
    end

    def json_result(obj, opts={})
      if yield(obj)
        json = success_json

        # If we were given a serializer, add the class to the json that comes back
        if opts[:serializer].present?
          json[obj.class.name.underscore] = opts[:serializer].new(obj, scope: guardian).serializable_hash
        end

        render json: MultiJson.dump(json)
      else
        error_obj = nil
        if opts[:additional_errors]
          error_target = opts[:additional_errors].find do |o|
            target = obj.send(o)
            target && target.errors.present?
          end
          error_obj = obj.send(error_target) if error_target
        end
        render_json_error(error_obj || obj)
      end
    end

    def mini_profiler_enabled?
      defined?(Rack::MiniProfiler) && guardian.is_developer?
    end

    def authorize_mini_profiler
      return unless mini_profiler_enabled?
      Rack::MiniProfiler.authorize_request
    end

    def check_xhr
      # bypass xhr check on PUT / POST / DELETE provided api key is there, otherwise calling api is annoying
      return if !request.get? && api_key_valid?
      raise RenderEmpty.new unless ((request.format && request.format.json?) || request.xhr?)
    end

    def ensure_logged_in
      raise Discourse::NotLoggedIn.new unless current_user.present?
    end

    def ensure_staff
      raise Discourse::InvalidAccess.new unless current_user && current_user.staff?
    end

    def destination_url
      request.original_url unless request.original_url =~ /uploads/
    end

    def redirect_to_login_if_required
      return if current_user || (request.format.json? && api_key_valid?)

      # redirect user to the SSO page if we need to log in AND SSO is enabled
      if SiteSetting.login_required?
        if SiteSetting.enable_sso?
          # save original URL in a session so we can redirect after login
          session[:destination_url] = destination_url
          redirect_to path('/session/sso')
        else
          # save original URL in a cookie (javascript redirects after login in this case)
          cookies[:destination_url] = destination_url
          redirect_to :login
        end
      end
    end

    def block_if_readonly_mode
      return if request.fullpath.start_with?(path "/admin/backups")
      raise Discourse::ReadOnly.new if !(request.get? || request.head?) && Discourse.readonly_mode?
    end

    def build_not_found_page(status=404, layout=false)
      category_topic_ids = Category.pluck(:topic_id).compact
      @container_class = "wrap not-found-container"
      @top_viewed = TopicQuery.new(nil, {except_topic_ids: category_topic_ids}).list_top_for("monthly").topics.first(10)
      @recent = Topic.where.not(id: category_topic_ids).recent(10)
      @slug =  params[:slug].class == String ? params[:slug] : ''
      @slug =  (params[:id].class == String ? params[:id] : '') if @slug.blank?
      @slug.gsub!('-',' ')
      render_to_string status: status, layout: layout, formats: [:html], template: '/exceptions/not_found'
    end

  protected

    def render_post_json(post, add_raw=true)
      post_serializer = PostSerializer.new(post, scope: guardian, root: false)
      post_serializer.add_raw = add_raw

      counts = PostAction.counts_for([post], current_user)
      if counts && counts = counts[post.id]
        post_serializer.post_actions = counts
      end
      render_json_dump(post_serializer)
    end

    def api_key_valid?
      request["api_key"] && ApiKey.where(key: request["api_key"]).exists?
    end

    # returns an array of integers given a param key
    # returns nil if key is not found
    def param_to_integer_list(key, delimiter = ',')
      if params[key]
        params[key].split(delimiter).map(&:to_i)
      end
    end

end
