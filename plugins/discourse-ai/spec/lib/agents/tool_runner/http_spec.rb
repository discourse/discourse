# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Agents::ToolRunner do
  fab!(:llm_model) { Fabricate(:llm_model, name: "claude-2") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:bot_user) { Discourse.system_user }

  def create_tool(script:)
    AiTool.create!(
      name: "test #{SecureRandom.uuid}",
      tool_name: "test_#{SecureRandom.uuid.underscore}",
      description: "test",
      parameters: [{ name: "query", type: "string", description: "perform a search" }],
      script: script,
      created_by_id: 1,
      summary: "Test tool summary",
    )
  end

  before { enable_current_plugin }

  describe "HTTP operations" do
    it "can base64 encode binary HTTP responses" do
      binary_data = (0..255).map(&:chr).join
      expected_base64 = Base64.strict_encode64(binary_data)

      script = <<~JS
        function invoke(params) {
          const result = http.post("https://example.com/binary", {
            body: "test",
            base64Encode: true
          });
          return result.body;
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({}, llm: nil, bot_user: nil)

      stub_request(:post, "https://example.com/binary").to_return(
        status: 200,
        body: binary_data,
        headers: {
        },
      )

      result = runner.invoke

      expect(result).to eq(expected_base64)
      expect(Base64.strict_decode64(result).bytes).to eq((0..255).to_a)
    end

    it "can base64 encode binary GET responses" do
      binary_data = (0..255).map(&:chr).join
      expected_base64 = Base64.strict_encode64(binary_data)

      script = <<~JS
        function invoke(params) {
          const result = http.get("https://example.com/binary", {
            base64Encode: true
          });
          return result.body;
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({}, llm: nil, bot_user: nil)

      stub_request(:get, "https://example.com/binary").to_return(
        status: 200,
        body: binary_data,
        headers: {
        },
      )

      result = runner.invoke

      expect(result).to eq(expected_base64)
      expect(Base64.strict_decode64(result).bytes).to eq((0..255).to_a)
    end

    it "can perform HTTP requests with various verbs" do
      %i[post put delete patch].each do |verb|
        script = <<~JS
        function invoke(params) {
          result = http.#{verb}("https://example.com/api",
            {
              headers: { TestHeader: "TestValue" },
              body: JSON.stringify({ data: params.data })
            }
          );

          return result.body;
        }
      JS

        tool = create_tool(script: script)
        runner = tool.runner({ "data" => "test data" }, llm: nil, bot_user: nil)

        stub_request(verb, "https://example.com/api").with(
          body: "{\"data\":\"test data\"}",
          headers: {
            "Accept" => "*/*",
            "Testheader" => "TestValue",
            "User-Agent" => "Discourse AI Bot 1.0 (https://www.discourse.org)",
          },
        ).to_return(status: 200, body: "Success", headers: {})

        result = runner.invoke

        expect(result).to eq("Success")
      end
    end

    it "can perform GET HTTP requests, with 1 param" do
      script = <<~JS
        function invoke(params) {
          result = http.get("https://example.com/" + params.query);
          return result.body;
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

      stub_request(:get, "https://example.com/test").with(
        headers: {
          "Accept" => "*/*",
          "User-Agent" => "Discourse AI Bot 1.0 (https://www.discourse.org)",
        },
      ).to_return(status: 200, body: "Hello World", headers: {})

      result = runner.invoke

      expect(result).to eq("Hello World")
    end

    it "is limited to MAX http requests" do
      script = <<~JS
        function invoke(params) {
          let i = 0;
          while (i < 21) {
            http.get("https://example.com/");
            i += 1;
          }
          return "will not happen";
        }
        JS

      tool = create_tool(script: script)
      runner = tool.runner({}, llm: nil, bot_user: nil)

      stub_request(:get, "https://example.com/").to_return(
        status: 200,
        body: "Hello World",
        headers: {
        },
      )

      expect { runner.invoke }.to raise_error(DiscourseAi::Agents::ToolRunner::TooManyRequestsError)
    end

    it "can perform GET HTTP requests" do
      script = <<~JS
        function invoke(params) {
          result = http.get("https://example.com/" + params.query,
            { headers: { TestHeader: "TestValue" } }
          );

          return result.body;
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

      stub_request(:get, "https://example.com/test").with(
        headers: {
          "Accept" => "*/*",
          "Testheader" => "TestValue",
          "User-Agent" => "Discourse AI Bot 1.0 (https://www.discourse.org)",
        },
      ).to_return(status: 200, body: "Hello World", headers: {})

      result = runner.invoke

      expect(result).to eq("Hello World")
    end

    it "will not timeout on slow HTTP reqs" do
      script = <<~JS
        function invoke(params) {
          result = http.get("https://example.com/" + params.query,
            { headers: { TestHeader: "TestValue" } }
          );

          return result.body;
        }
      JS

      tool = create_tool(script: script)
      runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

      stub_request(:get, "https://example.com/test").to_return do
        sleep 0.01
        { status: 200, body: "Hello World", headers: {} }
      end

      tool = create_tool(script: script)
      runner = tool.runner({ "query" => "test" }, llm: nil, bot_user: nil)

      runner.timeout = 10

      result = runner.invoke

      expect(result).to eq("Hello World")
    end
  end
end
