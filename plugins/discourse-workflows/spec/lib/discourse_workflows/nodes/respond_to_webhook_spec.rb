# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::RespondToWebhook::V1 do
  def rows(*values)
    { "values" => values }
  end

  def execute_response_node(configuration:, item:)
    request =
      DiscourseWorkflows::WebhookRequest.new(
        method: "POST",
        path: "test",
        webhook_url: "http://test.localhost/workflows/webhooks/test",
      )
    webhook_context = DiscourseWorkflows::WebhookContext.new(request: request)
    node = described_class.new(parameters: configuration)
    sandbox = DiscourseWorkflows::JsSandbox.new({ "$json" => item["json"] })
    resolver =
      DiscourseWorkflows::ExpressionResolver.new({ "$json" => item["json"] }, sandbox: sandbox)
    exec_ctx =
      DiscourseWorkflows::Executor::NodeExecutionContext.new(
        input_items: [item],
        resolver: resolver,
        parameters: configuration,
        property_schema: described_class.property_schema,
        webhook_context: webhook_context,
      )

    node.execute(exec_ctx)
    webhook_context.response
  ensure
    resolver&.dispose
    sandbox&.dispose
  end

  describe "#execute" do
    let(:item) { { "json" => { "user_id" => 42 } } }

    it "rejects redirects to domains not in the allow list" do
      config = { "response_type" => "redirect", "redirect_url" => "https://example.com/thanks" }
      response = execute_response_node(configuration: config, item: item)

      expect(response.status_code).to eq(400)
      expect(response.body).to eq(error: "invalid_redirect_url")
    end

    it "rejects protocol-relative redirect URLs" do
      config = {
        "response_type" => "redirect",
        "redirect_url" => "//example.com/thanks",
        "allowed_redirect_domains" => rows({ "domain" => "example.com" }),
      }
      response = execute_response_node(configuration: config, item: item)

      expect(response.status_code).to eq(400)
      expect(response.body).to eq(error: "invalid_redirect_url")
    end

    it "returns normalized allowed redirect domains" do
      config = {
        "response_type" => "redirect",
        "redirect_url" => "https://example.com/thanks",
        "allowed_redirect_domains" =>
          rows(
            { "domain" => " Example.com " },
            { "domain" => "*.Example.org" },
            { "domain" => "" },
          ),
      }
      response = execute_response_node(configuration: config, item: item)

      expect(response.status_code).to eq(302)
      expect(response.headers["Location"]).to eq("https://example.com/thanks")
    end

    it "returns JSON response data" do
      config = {
        "response_type" => "json",
        "status_code" => "201",
        "response_body" => '{"created": true}',
      }
      response = execute_response_node(configuration: config, item: item)

      expect(response.status_code).to eq(201)
      expect(response.body).to eq("created" => true)
    end

    it "keeps JSON null distinct from no data" do
      config = { "response_type" => "json", "response_body" => "null" }
      response = execute_response_node(configuration: config, item: item)

      expect(response.body).to be_nil
      expect(response).not_to be_no_body
    end

    it "returns text response data" do
      config = { "response_type" => "text", "status_code" => "200", "response_body" => "OK thanks" }
      response = execute_response_node(configuration: config, item: item)

      expect(response.status_code).to eq(200)
      expect(response.body).to eq("OK thanks")
      expect(response.headers["Content-Type"]).to eq("text/plain; charset=utf-8")
    end

    it "returns no data response" do
      config = { "response_type" => "no_data", "status_code" => "204" }
      response = execute_response_node(configuration: config, item: item)

      expect(response.status_code).to eq(204)
      expect(response.body).to be_nil
      expect(response).to be_no_body
    end

    it "defaults status code to 200 for json" do
      config = { "response_type" => "json", "response_body" => "{}" }
      response = execute_response_node(configuration: config, item: item)

      expect(response.status_code).to eq(200)
    end

    it "includes custom headers when provided" do
      config = {
        "response_type" => "json",
        "response_body" => "{}",
        "response_headers" => rows({ "key" => "X-Custom", "value" => "hello" }),
      }
      response = execute_response_node(configuration: config, item: item)

      expect(response.headers).to eq({ "X-Custom" => "hello" })
    end

    it "responds with the first incoming item" do
      config = { "response_type" => "first_incoming_item" }
      response = execute_response_node(configuration: config, item: item)

      expect(response.body).to eq("user_id" => 42)
    end
  end
end
