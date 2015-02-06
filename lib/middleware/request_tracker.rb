require_dependency 'middleware/anonymous_cache'

class Middleware::RequestTracker

  def initialize(app, settings={})
    @app = app
  end

  def self.log_request_on_site(result, env, helper=nil)
    host = RailsMultisite::ConnectionManagement.host(env)
    RailsMultisite::ConnectionManagement.with_hostname(host) do
      log_request(result,env,helper)
    end
  end

  PATH_PARAMS = "action_dispatch.request.path_parameters".freeze
  TRACK_VIEW = "HTTP_DISCOURSE_TRACK_VIEW".freeze


  def self.log_request(result,env,helper=nil)

    helper ||= Middleware::AnonymousCache::Helper.new(env)
    request = Rack::Request.new(env)

    status,headers = result
    status = status.to_i

    if (env[TRACK_VIEW] || (request.get? && !request.xhr? && headers["Content-Type"] =~ /text\/html/)) && status == 200
      if helper.is_crawler?
        ApplicationRequest.increment!(:page_view_crawler)
      elsif helper.has_auth_cookie?
        ApplicationRequest.increment!(:page_view_logged_in)
      else
        ApplicationRequest.increment!(:page_view_anon)
      end
    end

    ApplicationRequest.increment!(:http_total)

    if status >= 500
      ApplicationRequest.increment!(:http_5xx)
    elsif status >= 400
      ApplicationRequest.increment!(:http_4xx)
    elsif status >= 300
      ApplicationRequest.increment!(:http_3xx)
    else
      if request.path =~ /^\/message-bus\// || request.path == /\/topics\/timings/
        ApplicationRequest.increment!(:http_background)
      elsif status >= 200 && status < 300
        ApplicationRequest.increment!(:http_2xx)
      end
    end

  # rescue => ex
  #   Discourse.handle_exception(ex, {message: "Failed to log request"})
  end


  def call(env)
    result = @app.call(env)
  ensure
    Scheduler::Defer.later("Track view", _db=nil) do
      self.class.log_request_on_site(result,env)
    end
  end

end
