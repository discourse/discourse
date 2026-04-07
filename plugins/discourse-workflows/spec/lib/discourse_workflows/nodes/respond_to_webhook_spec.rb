# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::RespondToWebhook::V1 do
  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:respond_to_webhook")
    end
  end

  def execute_node(configuration:, item:)
    action = described_class.new(configuration: configuration)
    input_items = [item]
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => item.fetch("json") { {} } })
    exec_ctx =
      DiscourseWorkflows::NodeExecutionContext.new(input_items: input_items, resolver: resolver)
    items = action.execute(exec_ctx)[0]
    items.first["json"]
  end

  describe "#execute" do
    let(:item) { { "json" => { "user_id" => 42 } } }

    it "returns redirect response data" do
      config = { "response_type" => "redirect", "redirect_url" => "https://example.com/thanks" }
      result = execute_node(configuration: config, item: item)

      expect(result["response_type"]).to eq("redirect")
      expect(result["redirect_url"]).to eq("https://example.com/thanks")
      expect(result["status_code"]).to eq(302)
    end

    it "returns JSON response data" do
      config = {
        "response_type" => "json",
        "status_code" => "201",
        "response_body" => '{"created": true}',
      }
      result = execute_node(configuration: config, item: item)

      expect(result["response_type"]).to eq("json")
      expect(result["status_code"]).to eq(201)
      expect(result["response_body"]).to eq('{"created": true}')
    end

    it "returns text response data" do
      config = { "response_type" => "text", "status_code" => "200", "response_body" => "OK thanks" }
      result = execute_node(configuration: config, item: item)

      expect(result["response_type"]).to eq("text")
      expect(result["status_code"]).to eq(200)
      expect(result["response_body"]).to eq("OK thanks")
    end

    it "returns no data response" do
      config = { "response_type" => "no_data", "status_code" => "204" }
      result = execute_node(configuration: config, item: item)

      expect(result["response_type"]).to eq("no_data")
      expect(result["status_code"]).to eq(204)
    end

    it "defaults status code to 200 for json" do
      config = { "response_type" => "json", "response_body" => "{}" }
      result = execute_node(configuration: config, item: item)

      expect(result["status_code"]).to eq(200)
    end

    it "includes custom headers when provided" do
      config = {
        "response_type" => "json",
        "response_body" => "{}",
        "headers" => [{ "key" => "X-Custom", "value" => "hello" }],
      }
      result = execute_node(configuration: config, item: item)

      expect(result["headers"]).to eq({ "X-Custom" => "hello" })
    end
  end
end
