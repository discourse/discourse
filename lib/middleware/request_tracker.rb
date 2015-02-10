require_dependency 'middleware/anonymous_cache'

class Middleware::RequestTracker

  def initialize(app, settings={})
    @app = app
  end

  def self.log_request_on_site(data)
    host = RailsMultisite::ConnectionManagement.host(env)
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
      if data[:is_background]
        ApplicationRequest.increment!(:http_background)
      elsif status >= 200 && status < 300
        ApplicationRequest.increment!(:http_2xx)
      end
    end

  end

  TRACK_VIEW = "HTTP_DISCOURSE_TRACK_VIEW".freeze
  CONTENT_TYPE = "Content-Type".freeze
  def self.get_data(env,result)

    status,headers = result
    status = status.to_i

    helper = Middleware::AnonymousCache::Helper.new(env)
    request = Rack::Request.new(env)
    {
      status: status,
      is_crawler: helper.is_crawler?,
      has_auth_cookie: helper.has_auth_cookie?,
      is_background: request.path =~ /^\/message-bus\// || request.path == /\/topics\/timings/,
      track_view: (env[TRACK_VIEW] || (request.get? && !request.xhr? && headers[CONTENT_TYPE] =~ /text\/html/)) && status == 200
    }
  end

  def call(env)
    result = @app.call(env)
  ensure

    # we got to skip this on error ... its just logging
    data = self.class.get_data(env,result) rescue nil

    if data
      Scheduler::Defer.later("Track view", _db=nil) do
        self.class.log_request_on_site(data)
      end
    end

  end

end
