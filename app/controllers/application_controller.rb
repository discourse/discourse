require 'current_user'
require_dependency 'canonical_url'
require_dependency 'discourse'
require_dependency 'custom_renderer'
require_dependency 'archetype'
require_dependency 'rate_limiter'
require_dependency 'crawler_detection'
require_dependency 'json_error'
require_dependency 'letter_avatar'

class ApplicationController < ActionController::Base
  include CurrentUser
  include CanonicalURL::ControllerExtensions
  include JsonError

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
  before_filter :set_locale
  before_filter :set_mobile_view
  before_filter :inject_preview_style
  before_filter :disable_customization
  before_filter :block_if_readonly_mode
  before_filter :authorize_mini_profiler
  before_filter :store_incoming_links
  before_filter :preload_json
  before_filter :check_xhr
  before_filter :redirect_to_login_if_required

  layout :set_layout

  def has_escaped_fragment?
    SiteSetting.enable_escaped_fragments? && params.key?("_escaped_fragment_")
  end

  def set_layout
    has_escaped_fragment? || CrawlerDetection.crawler?(request.user_agent) ? 'crawler' : 'application'
  end

  rescue_from Exception do |exception|
    unless [ActiveRecord::RecordNotFound,
            ActionController::RoutingError,
            ActionController::UnknownController,
            AbstractController::ActionNotFound].include? exception.class
      begin
        ErrorLog.report_async!(exception, self, request, current_user)
      rescue
        # dont care give up
      end
    end
    raise
  end

  # Some exceptions
  class RenderEmpty < Exception; end

  # Render nothing unless we are an xhr request
  rescue_from RenderEmpty do
    render 'default/empty'
  end

  # If they hit the rate limiter
  rescue_from RateLimiter::LimitExceeded do |e|

    time_left = ""
    if e.available_in < 1.minute.to_i
      time_left = I18n.t("rate_limiter.seconds", count: e.available_in)
    elsif e.available_in < 1.hour.to_i
      time_left = I18n.t("rate_limiter.minutes", count: (e.available_in / 1.minute.to_i))
    else
      time_left = I18n.t("rate_limiter.hours", count: (e.available_in / 1.hour.to_i))
    end

    render json: {errors: [I18n.t("rate_limiter.too_many_requests", time_left: time_left)]}, status: 429
  end

  rescue_from Discourse::NotLoggedIn do |e|
    raise e if Rails.env.test?

    if request.get?
      redirect_to "/"
    else
      render status: 403, json: failed_json.merge(message: I18n.t(:not_logged_in))
    end

  end

  rescue_from Discourse::NotFound do
    rescue_discourse_actions("[error: 'not found']", 404) # TODO: this breaks json responses
  end

  rescue_from Discourse::InvalidAccess do
    rescue_discourse_actions("[error: 'invalid access']", 403, true) # TODO: this breaks json responses
  end

  rescue_from Discourse::ReadOnly do
    render status: 405, json: failed_json.merge(message: I18n.t("read_only_mode_enabled"))
  end

  def rescue_discourse_actions(message, error, include_ember=false)
    if request.format && request.format.json?
      # TODO: this doesn't make sense. Stuffing an html page into a json response will cause
      #       $.parseJSON to fail in the browser. Also returning text like "[error: 'invalid access']"
      #       from the above rescue_from blocks will fail because that isn't valid json.
      render status: error, layout: false, text: (error == 404) ? build_not_found_page(error) : message
    else
      render text: build_not_found_page(error, include_ember ? 'application' : 'no_js')
    end
  end

  def set_current_user_for_logs
    if current_user
      Logster.add_to_env(request.env,"username",current_user.username)
    end
  end

  def set_locale
    I18n.locale = if SiteSetting.allow_user_locale && current_user && current_user.locale.present?
                    current_user.locale
                  else
                    SiteSetting.default_locale
                  end
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
    return if request.xhr?

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
    if style.blank?
      session[:preview_style] = nil
    elsif style == "default"
      session[:preview_style] = ""
    else
      session[:preview_style] = style
    end
  end

  def disable_customization
    session[:disable_customization] = params[:customization] == "0" if params.has_key?(:customization)
  end

  def guardian
    @guardian ||= Guardian.new(current_user)
  end

  def serialize_data(obj, serializer, opts={})
    # If it's an array, apply the serializer as an each_serializer to the elements
    serializer_opts = {scope: guardian}.merge!(opts)
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
  def render_serialized(obj, serializer, opts={})
    render_json_dump(serialize_data(obj, serializer, opts))
  end

  def render_json_dump(obj)
    render json: MultiJson.dump(obj)
  end

  def can_cache_content?
    !current_user.present?
  end

  # Our custom cache method
  def discourse_expires_in(time_length)
    return unless can_cache_content?
    Middleware::AnonymousCache.anon_cache(request.env, time_length)
  end

  def fetch_user_from_params
    user = if params[:username]
      username_lower = params[:username].downcase
      username_lower.gsub!(/\.json$/, '')
      User.find_by(username_lower: username_lower)
    elsif params[:external_id]
      SingleSignOnRecord.find_by(external_id: params[:external_id]).try(:user)
    end
    raise Discourse::NotFound.new if user.blank?

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

  private

    def preload_anonymous_data
      store_preloaded("site", Site.json_for(guardian))
      store_preloaded("siteSettings", SiteSetting.client_settings_json)
      store_preloaded("customHTML", custom_html_json)
      store_preloaded("banner", banner_json)
    end

    def preload_current_user_data
      store_preloaded("currentUser", MultiJson.dump(CurrentUserSerializer.new(current_user, scope: guardian, root: false)))
      serializer = ActiveModel::ArraySerializer.new(TopicTrackingState.report([current_user.id]), each_serializer: TopicTrackingStateSerializer)
      store_preloaded("topicTrackingStates", MultiJson.dump(serializer))
    end

    def custom_html_json
      data = {
        top: SiteContent.content_for(:top),
        bottom: SiteContent.content_for(:bottom)
      }

      if SiteSetting.tos_accept_required && !current_user
        data[:tos_signup_form_message] = SiteContent.content_for(:tos_signup_form_message)
      end

      if DiscoursePluginRegistry.custom_html
        data.merge! DiscoursePluginRegistry.custom_html
      end

      MultiJson.dump(data)
    end

    def banner_json
      topic = Topic.where(archetype: Archetype.banner).limit(1).first
      banner = topic.present? ? topic.banner : {}

      MultiJson.dump(banner)
    end

    def render_json_error(obj)
      render json: MultiJson.dump(create_errors_json(obj)), status: 422
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
        render_json_error(obj)
      end
    end

    def mini_profiler_enabled?
      defined?(Rack::MiniProfiler) && current_user.try(:admin?)
    end

    def authorize_mini_profiler
      return unless mini_profiler_enabled?
      Rack::MiniProfiler.authorize_request
    end

    def store_incoming_links
      IncomingLink.add(request,current_user) unless request.xhr?
    end

    def check_xhr
      # bypass xhr check on PUT / POST / DELETE provided api key is there, otherwise calling api is annoying
      return if !request.get? && api_key_valid?
      raise RenderEmpty.new unless ((request.format && request.format.json?) || request.xhr?)
    end

    def ensure_logged_in
      raise Discourse::NotLoggedIn.new unless current_user.present?
    end

    def redirect_to_login_if_required
      return if current_user || (request.format.json? && api_key_valid?)

      redirect_to :login if SiteSetting.login_required?
    end

    def block_if_readonly_mode
      return if request.fullpath.start_with?("/admin/backups")
      raise Discourse::ReadOnly.new if !request.get? && Discourse.readonly_mode?
    end

    def build_not_found_page(status=404, layout=false)
      category_topic_ids = Category.pluck(:topic_id).compact
      @top_viewed = Topic.where.not(id: category_topic_ids).top_viewed(10)
      @recent = Topic.where.not(id: category_topic_ids).recent(10)
      @slug =  params[:slug].class == String ? params[:slug] : ''
      @slug =  (params[:id].class == String ? params[:id] : '') if @slug.blank?
      @slug.gsub!('-',' ')
      render_to_string status: status, layout: layout, formats: [:html], template: '/exceptions/not_found'
    end

  protected

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
