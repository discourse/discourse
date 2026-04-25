# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Agents::ToolRunner do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:bot_user) { Fabricate(:user, admin: true, refresh_auto_groups: true) }
  fab!(:tool) do
    AiTool.create!(
      name: "test_tool",
      tool_name: "test_tool",
      description: "a test tool",
      script: "function invoke(params) { return { result: 'ok' }; }",
      summary: "test",
      created_by: user,
    )
  end
  fab!(:llm_model)
  fab!(:ai_secret)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model.id) }

  before { enable_current_plugin }

  describe "#invoke" do
    it "can execute a simple script" do
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      result = runner.invoke
      expect(result).to eq({ "result" => "ok" })
    end

    it "exposes discourse.baseUrl" do
      tool.update!(script: "function invoke() { return { baseUrl: discourse.baseUrl }; }")
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      result = runner.invoke
      expect(result["baseUrl"]).to eq(Discourse.base_url)
    end

    it "allows scripts to resolve configured secret aliases" do
      tool.update!(
        secret_contracts: [{ alias: "external_api_key" }],
        script: "function invoke() { return { key: secrets.get('external_api_key') }; }",
      )
      AiToolSecretBinding.create!(
        ai_tool: tool,
        alias: "external_api_key",
        ai_secret_id: ai_secret.id,
      )

      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      result = runner.invoke

      expect(result["key"]).to eq(ai_secret.secret)
    end

    it "raises when secret alias is not bound" do
      tool.update!(
        secret_contracts: [{ alias: "external_api_key" }],
        script: "function invoke() { return secrets.get('external_api_key'); }",
      )

      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)

      expect { runner.invoke }.to raise_error(
        Discourse::InvalidParameters,
        /Missing required credential bindings/,
      )
    end

    it "resolves secrets from in-flight secret_bindings override" do
      tool.update!(
        secret_contracts: [{ alias: "external_api_key" }],
        script: "function invoke() { return { key: secrets.get('external_api_key') }; }",
      )

      bindings = [{ "alias" => "external_api_key", "ai_secret_id" => ai_secret.id }]

      runner =
        described_class.new(
          parameters: {
          },
          llm: llm,
          bot_user: bot_user,
          tool: tool,
          secret_bindings: bindings,
        )
      result = runner.invoke

      expect(result["key"]).to eq(ai_secret.secret)
    end
  end

  describe "#has_custom_system_message?" do
    it "returns true when script defines customSystemMessage function" do
      tool.update!(script: <<~JS)
          function invoke(params) { return {}; }
          function customSystemMessage() { return "extra system instructions"; }
        JS
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      expect(runner.has_custom_system_message?).to eq(true)
    end

    it "returns false when script does not define customSystemMessage" do
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      expect(runner.has_custom_system_message?).to eq(false)
    end
  end

  describe "#custom_system_message" do
    it "returns the string from customSystemMessage()" do
      tool.update!(script: <<~JS)
          function invoke(params) { return {}; }
          function customSystemMessage() { return "You are a coding assistant"; }
        JS
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      expect(runner.custom_system_message).to eq("You are a coding assistant")
    end

    it "returns nil when customSystemMessage returns null" do
      tool.update!(script: <<~JS)
          function invoke(params) { return {}; }
          function customSystemMessage() { return null; }
        JS
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      expect(runner.custom_system_message).to be_nil
    end

    it "returns nil when script errors" do
      tool.update!(script: <<~JS)
          function invoke(params) { return {}; }
          function customSystemMessage() { throw new Error("oops"); }
        JS
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      expect(runner.custom_system_message).to be_nil
    end
  end
end
