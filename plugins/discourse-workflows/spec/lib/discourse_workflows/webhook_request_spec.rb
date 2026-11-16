# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WebhookRequest do
  subject(:request) do
    described_class.new(
      method: "POST",
      path: "hook",
      headers: {
        "authorization" => "Bearer secret",
        "cookie" => "session=1",
        "x-api-key" => "key",
      },
      webhook_url: "http://test.localhost/workflows/webhooks/hook",
    )
  end

  it "masks sensitive headers" do
    expect(request.headers).to eq(
      "authorization" => "[FILTERED]",
      "cookie" => "[FILTERED]",
      "x-api-key" => "key",
    )
  end

  describe "#filter_header" do
    it "masks the given header" do
      request.filter_header("x-api-key")

      expect(request.headers["x-api-key"]).to eq("[FILTERED]")
    end

    it "ignores absent headers" do
      request.filter_header("x-missing")

      expect(request.headers).not_to have_key("x-missing")
    end
  end
end
