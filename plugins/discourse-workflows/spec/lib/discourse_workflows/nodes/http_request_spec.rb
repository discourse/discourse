# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::HttpRequest::V1 do
  describe "#execute" do
    let(:item) { { "json" => {} } }

    it "makes a GET request and returns parsed JSON response" do
      stub_request(:get, "https://api.example.com/data").to_return(
        status: 200,
        body: { result: "ok" }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = { "method" => "GET", "url" => "https://api.example.com/data" }
      result = execute_node(configuration: config, item: item)

      expect(result).to eq("result" => "ok")
    end

    it "returns full response data when enabled" do
      stub_request(:get, "https://api.example.com/data").to_return(
        status: 200,
        body: { result: "ok" }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "GET",
        "url" => "https://api.example.com/data",
        "full_response" => true,
      }
      result = execute_node(configuration: config, item: item)

      expect(result).to include(
        "body" => {
          "result" => "ok",
        },
        "headers" => include("content-type" => "application/json"),
        "status_code" => 200,
      )
      expect(result).to have_key("status_message")
    end

    it "splits top-level JSON array responses into separate output items" do
      stub_request(:get, "https://api.example.com/users").to_return(
        status: 200,
        body: [{ id: 1 }, { id: 2 }].to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = { "method" => "GET", "url" => "https://api.example.com/users" }
      result = execute_node_output(configuration: config, item: item).first

      expect(result.map { |output_item| output_item["json"] }).to eq([{ "id" => 1 }, { "id" => 2 }])
      expect(result.map { |output_item| output_item["pairedItem"] }).to eq(
        [{ "item" => 0 }, { "item" => 0 }],
      )
    end

    it "sends a JSON body with POST requests" do
      stub_request(:post, "https://api.example.com/data").with(body: '{"name":"test"}').to_return(
        status: 201,
        body: { id: 1 }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "POST",
        "url" => "https://api.example.com/data",
        "body_json" => '{"name":"test"}',
      }

      result = execute_node(configuration: config, item: item)

      expect(result).to eq("id" => 1)
    end

    it "sends fixed-collection query params resolved through the execution context" do
      stub_request(:get, "https://api.example.com/search").with(
        query: {
          "q" => "discourse",
          "page" => "2",
        },
      ).to_return(
        status: 200,
        body: { ok: true }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "GET",
        "url" => "https://api.example.com/search",
        "query_params" => {
          "values" => [
            { "key" => "q", "value" => "={{ $json.query }}" },
            { "key" => "page", "value" => "2" },
          ],
        },
      }

      result = execute_node(configuration: config, item: { "json" => { "query" => "discourse" } })

      expect(result).to eq("ok" => true)
    end

    it "sends fixed-collection form params resolved through the execution context" do
      stub_request(:post, "https://api.example.com/form").with(
        body: "name=Ada&role=admin",
        headers: {
          "Content-Type" => "application/x-www-form-urlencoded",
        },
      ).to_return(
        status: 200,
        body: { ok: true }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "POST",
        "url" => "https://api.example.com/form",
        "content_type" => "form_urlencoded",
        "body_form" => {
          "values" => [
            { "key" => "name", "value" => "={{ $json.name }}" },
            { "key" => "role", "value" => "admin" },
          ],
        },
      }

      result = execute_node(configuration: config, item: { "json" => { "name" => "Ada" } })

      expect(result).to eq("ok" => true)
    end

    it "raises an error for non-2xx status codes by default" do
      stub_request(:get, "https://api.example.com/fail").to_return(status: 404, body: "Not Found")

      config = { "method" => "GET", "url" => "https://api.example.com/fail" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        %r{HTTP GET https://api\.example\.com/fail failed with status 404},
      )
    end

    it "raises an error for server errors" do
      stub_request(:post, "https://api.example.com/error").to_return(
        status: 500,
        body: "Internal Server Error",
      )

      config = { "method" => "POST", "url" => "https://api.example.com/error", "body_json" => "{}" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        %r{HTTP POST https://api\.example\.com/error failed with status 500},
      )
    end

    it "filters query values in error messages" do
      stub_request(:get, "https://api.example.com/fail?token=secret-token").to_return(
        status: 404,
        body: "Not Found",
      )

      config = { "method" => "GET", "url" => "https://api.example.com/fail?token=secret-token" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "HTTP GET https://api.example.com/fail?token=[FILTERED] failed with status 404",
      )
    end

    it "returns non-JSON responses wrapped in a data key" do
      stub_request(:get, "https://example.com/page").to_return(
        status: 200,
        body: "<html>hello</html>",
        headers: {
          "content-type" => "text/html",
        },
      )

      config = { "method" => "GET", "url" => "https://example.com/page" }
      result = execute_node(configuration: config, item: item)

      expect(result).to eq("data" => "<html>hello</html>")
    end

    it "records request details in logs" do
      stub_request(:post, "https://api.example.com/data").with(
        headers: {
          "X-Custom-Header" => "my-value",
        },
      ).to_return(
        status: 200,
        body: { ok: true }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "POST",
        "url" => "https://api.example.com/data",
        "headers" => {
          "values" => [{ "key" => "X-Custom-Header", "value" => "my-value" }],
        },
        "body_json" => '{"name":"test"}',
      }

      action = described_class.new(parameters: config)
      sandbox = DiscourseWorkflows::JsSandbox.new({ "$json" => {} })
      resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => {} }, sandbox: sandbox)
      exec_ctx =
        DiscourseWorkflows::Executor::NodeExecutionContext.new(
          input_items: [item],
          resolver: resolver,
          parameters: config,
          property_schema: described_class.property_schema,
        )
      action.execute(exec_ctx)

      messages = exec_ctx.log.entries.map { |e| e["message"] }
      expect(messages).to eq(
        [
          "POST https://api.example.com/data",
          "X-Custom-Header: my-value",
          "Content-Type: application/json",
          "[body omitted]",
        ],
      )
      expect(exec_ctx.log.entries).to all(include("level" => "info"))
    ensure
      resolver&.dispose
      sandbox&.dispose
    end

    it "filters query values in logs" do
      stub_request(:get, "https://api.example.com/data?token=secret-token&page=2").to_return(
        status: 200,
        body: { ok: true }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )

      config = {
        "method" => "GET",
        "url" => "https://api.example.com/data?token=secret-token",
        "query_params" => {
          "values" => [{ "key" => "page", "value" => "2" }],
        },
      }
      messages = nil

      execute_node_output(configuration: config, item: item) do |exec_ctx|
        messages = exec_ctx.log.entries.map { |entry| entry["message"] }
      end

      expect(messages).to eq(["GET https://api.example.com/data?token=[FILTERED]&page=[FILTERED]"])
    end

    it "raises when URL has no host" do
      config = { "method" => "GET", "url" => "http:///path" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "URL must include a host.",
      )
    end

    context "with never_error enabled" do
      it "returns non-2xx responses without raising" do
        stub_request(:get, "https://api.example.com/missing").to_return(
          status: 404,
          body: { error: "not found" }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/missing",
          "never_error" => true,
        }

        result = execute_node(configuration: config, item: item)

        expect(result).to eq("error" => "not found")
      end

      it "returns non-2xx response status when full response is enabled" do
        stub_request(:get, "https://api.example.com/missing").to_return(
          status: 404,
          body: { error: "not found" }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/missing",
          "never_error" => true,
          "full_response" => true,
        }

        result = execute_node(configuration: config, item: item)

        expect(result).to include("status_code" => 404, "body" => { "error" => "not found" })
      end
    end

    context "with basic_auth authentication" do
      fab!(:credential) do
        Fabricate(
          :discourse_workflows_credential,
          credential_type: "basic_auth",
          data: {
            "user" => "api_user",
            "password" => "api_pass",
          },
        )
      end

      it "injects Authorization header" do
        stub_request(:get, "https://api.example.com/data").with(
          headers: {
            "Authorization" => "Basic #{Base64.strict_encode64("api_user:api_pass")}",
          },
        ).to_return(
          status: 200,
          body: { ok: true }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/data",
          "authentication" => "basic_auth",
          "credentials" => {
            "auth" => {
              "id" => credential.id,
              "credential_type" => "basic_auth",
            },
          },
        }

        result = execute_node(configuration: config, item: item)
        expect(result).to eq("ok" => true)
      end

      it "resolves credential expressions against each input item" do
        credential.update!(data: { "user" => "={{ $json.username }}", "password" => "api_pass" })

        stub_request(:get, "https://api.example.com/data").with(
          headers: {
            "Authorization" => "Basic #{Base64.strict_encode64("alice:api_pass")}",
          },
        ).to_return(
          status: 200,
          body: { user: "alice" }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )
        stub_request(:get, "https://api.example.com/data").with(
          headers: {
            "Authorization" => "Basic #{Base64.strict_encode64("bob:api_pass")}",
          },
        ).to_return(
          status: 200,
          body: { user: "bob" }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/data",
          "authentication" => "basic_auth",
          "credentials" => {
            "auth" => {
              "id" => credential.id,
              "credential_type" => "basic_auth",
            },
          },
        }
        input_items = [
          { "json" => { "username" => "alice" } },
          { "json" => { "username" => "bob" } },
        ]

        result = execute_node_output(configuration: config, input_items: input_items).first

        expect(result.map { |output_item| output_item["json"]["user"] }).to eq(%w[alice bob])
      end
    end

    context "with bearer_token authentication" do
      fab!(:credential) do
        Fabricate(
          :discourse_workflows_credential,
          credential_type: "bearer_token",
          data: {
            "token" => "my-secret-token",
          },
        )
      end

      it "injects Bearer Authorization header" do
        stub_request(:get, "https://api.example.com/data").with(
          headers: {
            "Authorization" => "Bearer my-secret-token",
          },
        ).to_return(
          status: 200,
          body: { ok: true }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/data",
          "authentication" => "bearer_token",
          "credentials" => {
            "auth" => {
              "id" => credential.id,
              "credential_type" => "bearer_token",
            },
          },
        }

        result = execute_node(configuration: config, item: item)
        expect(result).to eq("ok" => true)
      end

      it "logs the Authorization header with its value masked" do
        stub_request(:get, "https://api.example.com/data").to_return(
          status: 200,
          body: { ok: true }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/data",
          "authentication" => "bearer_token",
          "credentials" => {
            "auth" => {
              "id" => credential.id,
              "credential_type" => "bearer_token",
            },
          },
        }
        messages = nil

        execute_node_output(configuration: config, item: item) do |exec_ctx|
          messages = exec_ctx.log.entries.map { |entry| entry["message"] }
        end

        expect(messages).to include("Authorization: [FILTERED]")
        expect(messages).not_to include(a_string_including("my-secret-token"))
      end
    end

    context "with header_auth authentication" do
      fab!(:credential) do
        Fabricate(
          :discourse_workflows_credential,
          credential_type: "header_auth",
          data: {
            "name" => "X-API-Key",
            "value" => "my-secret-key",
          },
        )
      end

      it "injects the custom header" do
        stub_request(:get, "https://api.example.com/data").with(
          headers: {
            "X-API-Key" => "my-secret-key",
          },
        ).to_return(
          status: 200,
          body: { ok: true }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/data",
          "authentication" => "header_auth",
          "credentials" => {
            "auth" => {
              "id" => credential.id,
              "credential_type" => "header_auth",
            },
          },
        }

        result = execute_node(configuration: config, item: item)
        expect(result).to eq("ok" => true)
      end

      it "masks the custom auth header value in logs regardless of its name" do
        credential.update!(data: { "name" => "X-My-Api-Key", "value" => "my-secret-key" })

        stub_request(:get, "https://api.example.com/data").to_return(
          status: 200,
          body: { ok: true }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/data",
          "authentication" => "header_auth",
          "credentials" => {
            "auth" => {
              "id" => credential.id,
              "credential_type" => "header_auth",
            },
          },
        }
        messages = nil

        execute_node_output(configuration: config, item: item) do |exec_ctx|
          messages = exec_ctx.log.entries.map { |entry| entry["message"] }
        end

        expect(messages).to include("X-My-Api-Key: [FILTERED]")
        expect(messages).not_to include(a_string_including("my-secret-key"))
      end

      it "resolves credential expressions against each input item" do
        credential.update!(data: { "name" => "X-API-Key", "value" => "={{ $json.api_key }}" })

        stub_request(:get, "https://api.example.com/data").with(
          headers: {
            "X-API-Key" => "key-alice",
          },
        ).to_return(
          status: 200,
          body: { user: "alice" }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )
        stub_request(:get, "https://api.example.com/data").with(
          headers: {
            "X-API-Key" => "key-bob",
          },
        ).to_return(
          status: 200,
          body: { user: "bob" }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/data",
          "authentication" => "header_auth",
          "credentials" => {
            "auth" => {
              "id" => credential.id,
              "credential_type" => "header_auth",
            },
          },
        }
        input_items = [
          { "json" => { "api_key" => "key-alice" } },
          { "json" => { "api_key" => "key-bob" } },
        ]

        result = execute_node_output(configuration: config, input_items: input_items).first

        expect(result.map { |output_item| output_item["json"]["user"] }).to eq(%w[alice bob])
      end
    end

    context "with authentication set to none" do
      it "does not add Authorization header" do
        stub_request(:get, "https://api.example.com/data").to_return(
          status: 200,
          body: { ok: true }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )

        config = {
          "method" => "GET",
          "url" => "https://api.example.com/data",
          "authentication" => "none",
        }

        result = execute_node(configuration: config, item: item)
        expect(result).to eq("ok" => true)
      end
    end
  end
end
