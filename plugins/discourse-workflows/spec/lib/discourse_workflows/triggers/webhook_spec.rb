# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Triggers::Webhook do
  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:webhook")
    end
  end

  describe ".event_name" do
    it "returns nil" do
      expect(described_class.event_name).to be_nil
    end
  end

  describe ".configuration_schema" do
    it "defines path and http_method parameters" do
      schema = described_class.configuration_schema
      expect(schema[:path]).to eq({ type: :string, required: true })
      expect(schema[:http_method][:type]).to eq(:options)
      expect(schema[:http_method][:options]).to include(
        "GET",
        "POST",
        "PUT",
        "DELETE",
        "PATCH",
        "HEAD",
      )
      expect(schema[:http_method][:default]).to eq("GET")
      expect(schema.dig(:url_preview, :ui, :control)).to eq(:url_preview)
    end
  end

  describe ".output_schema" do
    it "includes body, headers, and query" do
      schema = described_class.output_schema
      expect(schema).to eq(
        body: :object,
        headers: :object,
        query: :object,
        method: :string,
        webhook_url: :string,
      )
    end
  end

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
