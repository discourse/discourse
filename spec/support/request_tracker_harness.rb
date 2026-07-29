# frozen_string_literal: true

module RequestTrackerHarness
  def env(overrides = {})
    path = overrides.delete(:path) || "/path?bla=1"
    create_request_env(path:).merge(
      "HTTP_HOST" => "http://test.com",
      "HTTP_USER_AGENT" =>
        "Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2228.0 Safari/537.36",
      "REQUEST_METHOD" => "GET",
      "HTTP_ACCEPT" =>
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8",
      "rack.input" => StringIO.new,
    ).merge(overrides)
  end

  def app(result, sql_calls: 0, redis_calls: 0, &block)
    lambda do |_env|
      sql_calls.times { User.where(id: -100).pluck(:id) }
      redis_calls.times { Discourse.redis.get("x") }
      block&.call
      result
    end
  end

  def log_tracked_view(value)
    data =
      Middleware::RequestTracker.get_data(
        env("HTTP_DISCOURSE_TRACK_VIEW" => value),
        ["200", { "Content-Type" => "text/html" }],
        0.2,
      )
    Middleware::RequestTracker.log_request(data)
  end

  def log_topic_view(topic:, auth_cookie:, authenticated:, deferred:)
    headers = { "action_dispatch.remote_ip" => "127.0.0.1" }
    headers["HTTP_COOKIE"] = "_t=#{auth_cookie};" if authenticated
    if deferred
      headers["HTTP_DISCOURSE_TRACK_VIEW"] = "1"
      headers["HTTP_DISCOURSE_TRACK_VIEW_DEFERRED"] = "1"
      headers["HTTP_DISCOURSE_TRACK_VIEW_TOPIC_ID"] = topic.id
      path = "/message-bus/abcde/poll"
    else
      headers["HTTP_DISCOURSE_TRACK_VIEW"] = "1"
      headers["HTTP_DISCOURSE_TRACK_VIEW_TOPIC_ID"] = topic.id
      path = URI.parse(topic.url).path
    end
    data =
      Middleware::RequestTracker.get_data(
        env(path:, **headers),
        ["200", { "Content-Type" => "text/html" }],
        0.1,
      )
    Middleware::RequestTracker.log_request(data)
    data
  end

  def log_browser_pageview(data)
    Middleware::RequestTracker.new(->(_env) { [200, {}, ["OK"]] }).log_later(data, {}, nil)
  end

  def beacon_env(body:, extra: {})
    env(
      {
        :path => "/srv/pv",
        "HTTP_HOST" => "test.localhost",
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "application/json",
        "rack.input" => StringIO.new(JSON.generate(body)),
      }.merge(extra),
    )
  end

  def engagement_env(body:, extra: {})
    env(
      {
        :path => "/srv/se",
        "HTTP_HOST" => "test.localhost",
        "REQUEST_METHOD" => "POST",
        "CONTENT_TYPE" => "application/json",
        "rack.input" => StringIO.new(JSON.generate(body)),
      }.merge(extra),
    )
  end
end
