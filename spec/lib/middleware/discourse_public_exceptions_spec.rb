# frozen_string_literal: true

RSpec.describe Middleware::DiscoursePublicExceptions do
  subject(:response) { described_class.new("/test").call(request_env) }

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

  it "does not log invalid MIME type requests" do
    ex = Middleware::DiscoursePublicExceptions.new("/test")

    ex.call(
      env(
        "HTTP_ACCEPT" => "../broken../",
        "action_dispatch.exception" => ActionController::RoutingError.new("abc"),
      ),
    )

    expect(fake_logger.warnings.length).to eq(0)
  end

  describe "#call" do
    let(:request_env) do
      env(
        "PATH_INFO" => "/404",
        "HTTP_ACCEPT" => "application/json",
        "action_dispatch.exception" => exception,
      )
    end

    shared_examples "a JSON not found response" do
      it "returns the not found error", :aggregate_failures do
        expect(response[0]).to eq(404)
        expect(response[1]["Content-Type"]).to eq("application/json; charset=utf-8")
        expect(JSON.parse(response[2].join)).to eq(
          "errors" => [I18n.t("not_found")],
          "error_type" => "not_found",
        )
      end

      it "prevents response caching" do
        expect(response[1]["Cache-Control"]).to eq("no-cache, no-store")
      end

      context "when back and forward cache compatibility is enabled" do
        before do
          allow(SiteSetting).to receive(:cache_control_bfcache_compatibility).and_return(true)
        end

        it "requires private response revalidation" do
          expect(response[1]["Cache-Control"]).to eq("no-cache, private")
        end
      end
    end

    before { allow(SiteSetting).to receive(:cache_control_bfcache_compatibility).and_return(false) }

    context "when the route does not exist" do
      let(:exception) { ActionController::RoutingError.new("No route matches") }

      it_behaves_like "a JSON not found response"
    end

    context "when the controller does not exist" do
      let(:exception) { ActionDispatch::MissingController.new("No controller matches") }

      it_behaves_like "a JSON not found response"
    end
  end
end
