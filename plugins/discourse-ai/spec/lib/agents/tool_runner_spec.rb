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

    it "combines multiple LLM text blocks before returning them to scripts" do
      tool.update!(script: <<~JS)
          function invoke() {
            return { result: llm.generate("Generate a greeting") };
          }
        JS
      result = nil
      DiscourseAi::Completions::Llm.with_prepared_responses([["hello ", "world"]]) do
        runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
        result = runner.invoke
      end

      expect(result["result"]).to eq("hello world")
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

  describe "#eval_with_timeout" do
    it "releases the watchdog promptly after script and attached callback errors" do
      runner = described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool)
      runner.mini_racer_context.attach(
        "failCallback",
        -> { raise ArgumentError, "callback failed" },
      )
      threads = Thread.list
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect { runner.eval_with_timeout('throw new Error("script failed")') }.to raise_error(
        MiniRacer::RuntimeError,
        /script failed/,
      )
      expect { runner.eval_with_timeout("function {") }.to raise_error(MiniRacer::ParseError)
      expect { runner.eval_with_timeout("failCallback()") }.to raise_error(
        ArgumentError,
        "callback failed",
      )

      expect(Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at).to be < 1
      expect(Thread.list - threads).to be_empty
      expect(runner.eval_with_timeout("1 + 1")).to eq(2)
    end

    it "terminates runaway scripts and releases their watchdog" do
      tool.update!(script: "function invoke() { while (true) {} }")
      runner =
        described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool, timeout: 10)
      threads = Thread.list

      expect(runner.invoke).to eq(error: "Script terminated due to timeout")
      expect(Thread.list - threads).to be_empty
      expect(runner.eval_with_timeout("1 + 1")).to eq(2)
    end

    it "excludes time spent in attached functions from the script timeout" do
      runner =
        described_class.new(parameters: {}, llm: llm, bot_user: bot_user, tool: tool, timeout: 10)
      expect(runner.eval_with_timeout("sleep(50); 42")).to eq(42)
    end
  end

  describe "#has_custom_system_message?" do
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
      expect(runner.has_custom_system_message?).to eq(true)
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
