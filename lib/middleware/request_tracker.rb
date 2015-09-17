require_dependency 'middleware/anonymous_cache'

class Middleware::RequestTracker

  def initialize(app, settings={})
    @app = app
  end

  def self.log_request_on_site(data,host)
    RailsMultisite::ConnectionManagement.with_hostname(host) do
      log_request(data)
    end
  end

  def self.log_request(data)
    status = data[:status]
    track_view = data[:track_view]

    if track_view
      if data[:is_crawler]
        ApplicationRequest.increment!(:page_view_crawler)
      elsif data[:has_auth_cookie]
        ApplicationRequest.increment!(:page_view_logged_in)
        ApplicationRequest.increment!(:page_view_logged_in_mobile) if data[:is_mobile]
      else
        ApplicationRequest.increment!(:page_view_anon)
        ApplicationRequest.increment!(:page_view_anon_mobile) if data[:is_mobile]
      end
    end

    ApplicationRequest.increment!(:http_total)

    if status >= 500
      ApplicationRequest.increment!(:http_5xx)
    elsif data[:is_background]
      ApplicationRequest.increment!(:http_background)
    elsif status >= 400
      ApplicationRequest.increment!(:http_4xx)
    elsif status >= 300
      ApplicationRequest.increment!(:http_3xx)
    elsif status >= 200 && status < 300
      ApplicationRequest.increment!(:http_2xx)
    end

  end

  TRACK_VIEW = "HTTP_DISCOURSE_TRACK_VIEW".freeze
  CONTENT_TYPE = "Content-Type".freeze
  def self.get_data(env,result)
    status,headers = result
    status = status.to_i

    helper = Middleware::AnonymousCache::Helper.new(env)
    request = Rack::Request.new(env)

    env_track_view = env[TRACK_VIEW]
    track_view = status == 200
    track_view &&= env_track_view != "0".freeze && env_track_view != "false".freeze
    track_view &&= env_track_view || (request.get? && !request.xhr? && headers[CONTENT_TYPE] =~ /text\/html/)
    track_view = !!track_view

    {
      status: status,
      is_crawler: helper.is_crawler?,
      has_auth_cookie: helper.has_auth_cookie?,
      is_background: request.path =~ /^\/message-bus\// || request.path == /\/topics\/timings/,
      is_mobile: helper.is_mobile?,
      track_view: track_view
    }
  end

  def call(env)
    result = @app.call(env)
  ensure

    # we got to skip this on error ... its just logging
    data = self.class.get_data(env,result) rescue nil
    host = RailsMultisite::ConnectionManagement.host(env)

    if data
      log_later(data,host)
    end

  end

  def log_later(data,host)
    Scheduler::Defer.later("Track view", _db=nil) do
      self.class.log_request_on_site(data,host)
    end
  end

end
