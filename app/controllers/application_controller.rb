require 'current_user'
require_dependency 'canonical_url'
require_dependency 'discourse'
require_dependency 'custom_renderer'
require_dependency 'archetype'
require_dependency 'rate_limiter'

class ApplicationController < ActionController::Base
  include CurrentUser
  include CanonicalURL::ControllerExtensions

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

  before_filter :set_mobile_view
  before_filter :inject_preview_style
  before_filter :block_if_maintenance_mode
  before_filter :authorize_mini_profiler
  before_filter :store_incoming_links
  before_filter :preload_json
  before_filter :check_xhr
  before_filter :set_locale
  before_filter :redirect_to_login_if_required

  rescue_from Exception do |exception|
    unless [ ActiveRecord::RecordNotFound, ActionController::RoutingError,
             ActionController::UnknownController, AbstractController::ActionNotFound].include? exception.class
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
    redirect_to "/"
  end

  rescue_from Discourse::NotFound do
    rescue_discourse_actions("[error: 'not found']", 404)
  end

  rescue_from Discourse::InvalidAccess do
    rescue_discourse_actions("[error: 'invalid access']", 403)
  end

  def rescue_discourse_actions(message, error)
    if request.format && request.format.json?
      render status: error, layout: false, text: (error == 404) ? build_not_found_page(error) : message
    else
      render text: build_not_found_page(error, 'no_js')
    end
  end

  def set_locale
    I18n.locale = SiteSetting.default_locale
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
    session[:preview_style] = style if style
  end

  def guardian
    @guardian ||= Guardian.new(current_user)
  end

  def serialize_data(obj, serializer, opts={})
    # If it's an array, apply the serializer as an each_serializer to the elements
    serializer_opts = {scope: guardian}.merge!(opts)
    if obj.is_a?(Array) or obj.is_a?(ActiveRecord::Associations::CollectionProxy)
      serializer_opts[:each_serializer] = serializer
      ActiveModel::ArraySerializer.new(obj, serializer_opts).as_json
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
    Middleware::AnonymousCache.anon_cache(request.env, 1.minute)
  end

  def fetch_user_from_params
    username_lower = params[:username].downcase
    username_lower.gsub!(/\.json$/, '')

    user = User.where(username_lower: username_lower).first
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
      store_preloaded("site", Site.cached_json(guardian))
      store_preloaded("siteSettings", SiteSetting.client_settings_json)
    end

    def preload_current_user_data
      store_preloaded("currentUser", MultiJson.dump(CurrentUserSerializer.new(current_user, root: false)))
      serializer = ActiveModel::ArraySerializer.new(TopicTrackingState.report([current_user.id]), each_serializer: TopicTrackingStateSerializer)
      store_preloaded("topicTrackingStates", MultiJson.dump(serializer))
    end

    def render_json_error(obj)
      if obj.present?
        render json: MultiJson.dump(errors: obj.errors.full_messages), status: 422
      else
        render json: MultiJson.dump(errors: [I18n.t('js.generic_error')]), status: 422
      end
    end

    def success_json
      {success: 'OK'}
    end

    def failed_json
      {failed: 'FAILED'}
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

    def block_if_maintenance_mode
      if Discourse.maintenance_mode?
        if request.format.json?
          render status: 503, json: failed_json.merge(message: I18n.t('site_under_maintenance'))
        else
          render status: 503, file: File.join( Rails.root, 'public', '503.html' ), layout: false
        end
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
      redirect_to :login if SiteSetting.login_required? && !current_user
    end

    def build_not_found_page(status=404, layout=false)
      @top_viewed = TopicQuery.top_viewed(10)
      @recent = TopicQuery.recent(10)
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
