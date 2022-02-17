# frozen_string_literal: true

require "rails_helper"

describe Middleware::DiscoursePublicExceptions do
  before do
    @orig_logger = Rails.logger
    Rails.logger = @fake_logger = FakeLogger.new
  end

  after do
    Rails.logger = @orig_logger
  end

  def env(opts = {})
    {
      "HTTP_HOST" => "http://test.com",
      "REQUEST_URI" => "/path?bla=1",
      "REQUEST_METHOD" => "GET",
      "rack.input" => ""
    }.merge(opts)
  end

  it "should not log for invalid mime type requests" do
    ex = Middleware::DiscoursePublicExceptions.new("/test")

    ex.call(env(
      "HTTP_ACCEPT" => "../broken../",
      "action_dispatch.exception" => ActionController::RoutingError.new("abc")
    ))

    expect(@fake_logger.warnings.length).to eq(0)
  end

end
