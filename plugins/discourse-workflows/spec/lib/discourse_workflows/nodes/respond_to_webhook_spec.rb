# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::RespondToWebhook::V1 do
  subject(:webhook_response) do
    described_class.new(parameters: configuration).execute(execution_context)
    webhook_context.response
  end

  let(:configuration) { {} }
  let(:request) do
    DiscourseWorkflows::WebhookRequest.new(
      method: "POST",
      path: "test",
      webhook_url: "http://test.localhost/workflows/webhooks/test",
    )
  end
  let(:webhook_context) { DiscourseWorkflows::WebhookContext.new(request: request) }
  let(:sandbox) { DiscourseWorkflows::JsSandbox.new({ "$json" => item["json"] }) }
  let(:resolver) do
    DiscourseWorkflows::ExpressionResolver.new({ "$json" => item["json"] }, sandbox: sandbox)
  end
  let(:execution_context) do
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [item],
      resolver: resolver,
      parameters: configuration,
      property_schema: described_class.property_schema,
      webhook_context: webhook_context,
    )
  end

  after do
    resolver.dispose
    sandbox.dispose
  end

  describe "#execute" do
    let(:item) { { "json" => { "user_id" => 42 } } }

    context "with a redirect outside the allow list" do
      let(:configuration) do
        { "response_type" => "redirect", "redirect_url" => "https://example.com/thanks" }
      end

      it "rejects the redirect" do
        expect(webhook_response.status_code).to eq(400)
        expect(webhook_response.body).to eq(error: "invalid_redirect_url")
      end
    end

    context "with a protocol-relative redirect URL" do
      let(:configuration) do
        {
          "response_type" => "redirect",
          "redirect_url" => "//example.com/thanks",
          "allowed_redirect_domains" => {
            "values" => [{ "domain" => "example.com" }],
          },
        }
      end

      it "rejects the redirect" do
        expect(webhook_response.status_code).to eq(400)
        expect(webhook_response.body).to eq(error: "invalid_redirect_url")
      end
    end

    context "with normalized allowed redirect domains" do
      let(:configuration) do
        {
          "response_type" => "redirect",
          "redirect_url" => "https://example.com/thanks",
          "allowed_redirect_domains" => {
            "values" => [
              { "domain" => " Example.com " },
              { "domain" => "*.Example.org" },
              { "domain" => "" },
            ],
          },
        }
      end

      it "returns the redirect" do
        expect(webhook_response.status_code).to eq(302)
        expect(webhook_response.headers["Location"]).to eq("https://example.com/thanks")
      end
    end

    context "with JSON response data" do
      let(:configuration) do
        {
          "response_type" => "json",
          "status_code" => "201",
          "response_body" => '{"created": true}',
        }
      end

      it "returns the configured response" do
        expect(webhook_response.status_code).to eq(201)
        expect(webhook_response.body).to eq("created" => true)
      end
    end

    context "with a JSON null response" do
      let(:configuration) { { "response_type" => "json", "response_body" => "null" } }

      it "keeps null distinct from no data" do
        expect(webhook_response.body).to be_nil
        expect(webhook_response).not_to be_no_body
      end
    end

    context "with text response data" do
      let(:configuration) do
        { "response_type" => "text", "status_code" => "200", "response_body" => "OK thanks" }
      end

      it "returns the configured response" do
        expect(webhook_response.status_code).to eq(200)
        expect(webhook_response.body).to eq("OK thanks")
        expect(webhook_response.headers["Content-Type"]).to eq("text/plain; charset=utf-8")
      end
    end

    context "with no response data" do
      let(:configuration) { { "response_type" => "no_data", "status_code" => "204" } }

      it "returns a no-body response" do
        expect(webhook_response.status_code).to eq(204)
        expect(webhook_response.body).to be_nil
        expect(webhook_response).to be_no_body
      end
    end

    context "with JSON and no status code" do
      let(:configuration) { { "response_type" => "json", "response_body" => "{}" } }

      it "defaults the status code to 200" do
        expect(webhook_response.status_code).to eq(200)
      end
    end

    context "with custom headers" do
      let(:configuration) do
        {
          "response_type" => "json",
          "response_body" => "{}",
          "response_headers" => {
            "values" => [{ "key" => "X-Custom", "value" => "hello" }],
          },
        }
      end

      it "includes them" do
        expect(webhook_response.headers).to eq({ "X-Custom" => "hello" })
      end
    end

    context "with the first incoming item response type" do
      let(:configuration) { { "response_type" => "first_incoming_item" } }

      it "responds with the item" do
        expect(webhook_response.body).to eq("user_id" => 42)
      end
    end
  end
end
