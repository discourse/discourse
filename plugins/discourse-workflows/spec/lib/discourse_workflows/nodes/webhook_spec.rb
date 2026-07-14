# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Webhook::V1 do
  describe "#output" do
    it "returns request data" do
      trigger =
        described_class.new(
          body: {
            "foo" => "bar",
          },
          headers: {
            "content-type" => "application/json",
          },
          params: {
            "path" => "my-hook",
          },
          query: {
            "page" => "1",
          },
          method: "POST",
          webhook_url: "http://test.localhost/workflows/webhooks/my-hook",
          raw_body: '{"foo":"bar"}',
        )
      output = trigger.output

      expect(output[:body]).to eq({ "foo" => "bar" })
      expect(output[:headers]).to eq({ "content-type" => "application/json" })
      expect(output[:params]).to eq({ "path" => "my-hook" })
      expect(output[:query]).to eq({ "page" => "1" })
      expect(output[:method]).to eq("POST")
      expect(output[:webhook_url]).to eq("http://test.localhost/workflows/webhooks/my-hook")
      expect(output[:raw_body]).to eq('{"foo":"bar"}')
    end
  end
end
