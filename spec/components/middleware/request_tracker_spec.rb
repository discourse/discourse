require "spec_helper"
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
    it "can log requests correctly" do
      freeze_time Time.now

      ApplicationRequest.clear_cache!

      Middleware::RequestTracker.log_request(["200",{"Content-Type" => 'text/html'}], env(
        "HTTP_USER_AGENT" => "AdsBot-Google (+http://www.google.com/adsbot.html)"
      ))
      Middleware::RequestTracker.log_request(["200",{}], env(
        "HTTP_DISCOURSE_TRACK_VIEW" => "1"
      ))

      ApplicationRequest.write_cache!

      ApplicationRequest.http_total.first.count.should == 2
      ApplicationRequest.http_2xx.first.count.should == 2

      ApplicationRequest.page_view_anon.first.count.should == 1
      ApplicationRequest.page_view_crawler.first.count.should == 1
    end
  end
end
