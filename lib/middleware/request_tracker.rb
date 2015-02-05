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

  def self.log_request(result,env,helper=nil)

    helper ||= Middleware::AnonymousCache::Helper.new(env)
    params = env[PATH_PARAMS]
    request = Rack::Request.new(env)

    ApplicationRequest.increment!(:total)

    status,_ = result
    status = status.to_i

    if status >= 500
      ApplicationRequest.increment!(:server_error)
    elsif status >= 400
      ApplicationRequest.increment!(:client_error)
    elsif status >= 300
      ApplicationRequest.increment!(:redirect)
    end

    if request.path =~ /^\/message-bus\// || request.path == /\/topics\/timings/
      ApplicationRequest.increment!(:background)
    elsif status >= 200 && status < 300
      ApplicationRequest.increment!(:success)
    end

    if params && params[:controller] == "topics" && params[:action] == "show"
      if helper.is_crawler?
        ApplicationRequest.increment!(:topic_crawler)
      elsif helper.has_auth_cookie?
        ApplicationRequest.increment!(:topic_logged_in)
      else
        ApplicationRequest.increment!(:topic_anon)
      end
    end

  rescue => ex
    Discourse.handle_exception(ex, {message: "Failed to log request"})
  end


  def call(env)
    result = @app.call(env)
  ensure
    Scheduler::Defer.later("Track view", _db=nil) do
      self.class.log_request_on_site(result,env)
    end
  end

end
