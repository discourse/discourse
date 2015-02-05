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

      Middleware::RequestTracker.log_request(["200"], env(
        "HTTP_USER_AGENT" => "AdsBot-Google (+http://www.google.com/adsbot.html)",
        "action_dispatch.request.path_parameters" => {controller: "topics", action: "show"}
      ))
      Middleware::RequestTracker.log_request(["200"], env(
        "action_dispatch.request.path_parameters" => {controller: "topics", action: "show"}
      ))

      ApplicationRequest.write_cache!

      ApplicationRequest.total.first.count.should == 2
      ApplicationRequest.success.first.count.should == 2

      ApplicationRequest.topic_anon.first.count.should == 1
      ApplicationRequest.topic_crawler.first.count.should == 1
    end
  end
end
