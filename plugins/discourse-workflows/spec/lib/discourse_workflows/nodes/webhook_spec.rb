# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Webhook::V1 do
  describe "#output" do
    it "returns body, headers, and query" do
      trigger =
        described_class.new(
          body: {
            "foo" => "bar",
          },
          headers: {
            "content-type" => "application/json",
          },
          query: {
            "page" => "1",
          },
          method: "POST",
          webhook_url: "http://test.localhost/workflows/webhooks/my-hook",
        )
      output = trigger.output

      expect(output[:body]).to eq({ "foo" => "bar" })
      expect(output[:headers]).to eq({ "content-type" => "application/json" })
      expect(output[:query]).to eq({ "page" => "1" })
      expect(output[:method]).to eq("POST")
      expect(output[:webhook_url]).to eq("http://test.localhost/workflows/webhooks/my-hook")
    end
  end
end
