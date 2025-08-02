# frozen_string_literal: true

RSpec.describe Middleware::DiscoursePublicExceptions do
  let(:fake_logger) { FakeLogger.new }

  before { Rails.logger.broadcast_to(fake_logger) }

  after { Rails.logger.stop_broadcasting_to(fake_logger) }

  def env(opts = {})
    {
      "HTTP_HOST" => "http://test.com",
      "REQUEST_URI" => "/path?bla=1",
      "REQUEST_METHOD" => "GET",
      "rack.input" => "",
    }.merge(opts)
  end

  it "should not log for invalid mime type requests" do
    ex = Middleware::DiscoursePublicExceptions.new("/test")

    ex.call(
      env(
        "HTTP_ACCEPT" => "../broken../",
        "action_dispatch.exception" => ActionController::RoutingError.new("abc"),
      ),
    )

    expect(fake_logger.warnings.length).to eq(0)
  end
end
