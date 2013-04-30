require 'current_user'
require 'canonical_url'
require_dependency 'discourse'
require_dependency 'custom_renderer'
require 'archetype'
require_dependency 'rate_limiter'

class ApplicationController < ActionController::Base
  include CurrentUser

  include CanonicalURL::ControllerExtensions

  serialization_scope :guardian

  protect_from_forgery

  before_filter :inject_preview_style
  before_filter :block_if_maintenance_mode
  before_filter :check_restricted_access
  before_filter :authorize_mini_profiler
  before_filter :store_incoming_links
  before_filter :preload_json
  before_filter :check_xhr
  before_filter :set_locale

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
    redirect_to root_path
  end

  rescue_from Discourse::NotFound do
    if !request.format || request.format.html?
      # for now do a simple remap, we may look at cleaner ways of doing the render
      #
      # Sam: I am confused about this, we need a comment that explains why this is conditional
      raise ActiveRecord::RecordNotFound
    else
      render file: 'public/404', formats: [:html], layout: false, status: 404
    end
  end

  rescue_from Discourse::InvalidAccess do
    render file: 'public/403', formats: [:html], layout: false, status: 403
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
    if request.format && request.format.html?
      if guardian.current_user
        guardian.current_user.sync_notification_channel_position
      end

      store_preloaded("site", Site.cached_json)

      if current_user.present?
        store_preloaded("currentUser", MultiJson.dump(CurrentUserSerializer.new(current_user, root: false)))
      end
      store_preloaded("siteSettings", SiteSetting.client_settings_json)
    end
  end


  def inject_preview_style
    style = request['preview-style']
    session[:preview_style] = style if style
  end

  def guardian
    @guardian ||= Guardian.new(current_user)
  end

  # This is odd, but it seems that in Rails `render json: obj` is about
  # 20% slower than calling MultiJSON.dump ourselves. I'm not sure why
  # Rails doesn't call MultiJson.dump when you pass it json: obj but
  # it seems we don't need whatever Rails is doing.
  def render_serialized(obj, serializer, opts={})

    # If it's an array, apply the serializer as an each_serializer to the elements
    serializer_opts = {scope: guardian}.merge!(opts)
    if obj.is_a?(Array)
      serializer_opts[:each_serializer] = serializer
      render_json_dump(ActiveModel::ArraySerializer.new(obj, serializer_opts).as_json)
    else
      render_json_dump(serializer.new(obj, serializer_opts).as_json)
    end

  end

  def render_json_dump(obj)
    render json: MultiJson.dump(obj)
  end

  def can_cache_content?
    # Don't cache unless we're in production mode
    return false unless Rails.env.production? || Rails.env == "profile"

    # Don't cache logged in users
    return false if current_user.present?

    # Don't cache if there's restricted access
    return false if SiteSetting.access_password.present?

    true
  end

  # Our custom cache method
  def discourse_expires_in(time_length)
    return unless can_cache_content?
    expires_in time_length, public: true
  end

  # Helper method - if no logged in user (anonymous), use Rails' conditional GET
  # support. Should be very fast behind a cache.
  def anonymous_etag(*args)
    if can_cache_content?
      yield if stale?(*args)

      # Add a one minute expiry
      expires_in 1.minute, public: true
    else
      yield
    end
  end

  private

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

    def check_restricted_access
      # note current_user is defined in the CurrentUser mixin
      if SiteSetting.access_password.present? && cookies[:_access] != SiteSetting.access_password
        redirect_to request_access_path(return_path: request.fullpath)
        return false
      end
    end

    def mini_profiler_enabled?
      defined?(Rack::MiniProfiler) && current_user.try(:admin?)
    end

    def authorize_mini_profiler
      return unless mini_profiler_enabled?
      Rack::MiniProfiler.authorize_request
    end

    def requires_parameters(*required)
      required.each do |p|
        raise Discourse::InvalidParameters.new(p) unless params.has_key?(p)
      end
    end

    alias :requires_parameter :requires_parameters

    def store_incoming_links
      IncomingLink.add(request,current_user) unless request.xhr?
    end

    def check_xhr
      unless (controller_name == 'forums' || controller_name == 'user_open_ids')
        # bypass xhr check on PUT / POST / DELETE provided api key is there, otherwise calling api is annoying
        return if !request.get? && request["api_key"] && SiteSetting.api_key_valid?(request["api_key"])
        raise RenderEmpty.new unless ((request.format && request.format.json?) || request.xhr?)
      end
    end

    def ensure_logged_in
      raise Discourse::NotLoggedIn.new unless current_user.present?
    end

end
