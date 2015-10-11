require "rails_helper"
require_dependency "middleware/request_tracker"

describe Middleware::RequestTracker do

  def env(opts={})
    {
      "HTTP_HOST" => "http://test.com",
      "REQUEST_URI" => "/path?bla=1",
      "REQUEST_METHOD" => "GET",
      "rack.input" => ""
    }.merge(opts)
  end

  context "log_request" do
    before do
      freeze_time Time.now
      ApplicationRequest.clear_cache!
    end

    def log_tracked_view(val)
      data = Middleware::RequestTracker.get_data(env(
        "HTTP_DISCOURSE_TRACK_VIEW" => val
      ), ["200",{"Content-Type" => 'text/html'}])

      Middleware::RequestTracker.log_request(data)
    end

    it "can exclude/include based on custom header" do
      log_tracked_view("true")
      log_tracked_view("1")
      log_tracked_view("false")
      log_tracked_view("0")
      ApplicationRequest.write_cache!

      expect(ApplicationRequest.page_view_anon.first.count).to eq(2)
    end

    it "can log requests correctly" do

      data = Middleware::RequestTracker.get_data(env(
        "HTTP_USER_AGENT" => "AdsBot-Google (+http://www.google.com/adsbot.html)"
      ), ["200",{"Content-Type" => 'text/html'}])

      Middleware::RequestTracker.log_request(data)

      data = Middleware::RequestTracker.get_data(env(
        "HTTP_DISCOURSE_TRACK_VIEW" => "1"
      ), ["200",{}])

      Middleware::RequestTracker.log_request(data)

      data = Middleware::RequestTracker.get_data(env(
        "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"
      ), ["200",{"Content-Type" => 'text/html'}])

      Middleware::RequestTracker.log_request(data)

      ApplicationRequest.write_cache!

      expect(ApplicationRequest.http_total.first.count).to eq(3)
      expect(ApplicationRequest.http_2xx.first.count).to eq(3)

      expect(ApplicationRequest.page_view_anon.first.count).to eq(2)
      expect(ApplicationRequest.page_view_crawler.first.count).to eq(1)
      expect(ApplicationRequest.page_view_anon_mobile.first.count).to eq(1)
    end
  end
end
