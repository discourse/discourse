# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::JsSandbox do
  subject(:sandbox) do
    described_class
      .new(workflow_context, user: user, vars: vars)
      .tap { |instance| owned_sandboxes << instance }
  end

  fab!(:user)

  let(:workflow_context) { { "$trigger" => { "topic_id" => 42 } } }
  let(:vars) { { "API_URL" => "https://example.com" } }
  let(:owned_sandboxes) { [] }

  after { owned_sandboxes.each(&:dispose) }

  describe "timeout" do
    it "raises when JS execution exceeds the time limit" do
      expect { sandbox.eval("while(true) {}") }.to raise_error(
        DiscourseWorkflows::JsSandbox::BudgetExceededError,
        /exceeded #{DiscourseWorkflows::JsSandbox::EVAL_TIMEOUT_MS}ms time limit/,
      )
    end
  end

  describe "memory limit" do
    it "raises when JS allocates too much memory" do
      # a generous timeout keeps the memory cap as the only limit that can
      # fire, even on a slow CI box
      stub_const(DiscourseWorkflows::JsSandbox, :EVAL_TIMEOUT_MS, 5_000) do
        expect { sandbox.eval(<<~JS) }.to raise_error(DiscourseWorkflows::JsSandbox::SandboxError)
          var a = [];
          while(true) { a.push(new Array(100000).fill(1.5)); }
        JS
      end
    end
  end

  describe "site setting filtering" do
    it "returns [FILTERED] for secret settings" do
      SiteSetting.secret_settings << :some_secret_key
      result = sandbox.eval("$site_settings.some_secret_key")
      expect(result).to eq("[FILTERED]")
    ensure
      SiteSetting.secret_settings.delete(:some_secret_key)
    end

    it "returns [FILTERED] for hidden settings" do
      SiteSetting.stubs(:hidden_settings).returns(Set.new([:some_hidden_key]))
      result = sandbox.eval("$site_settings.some_hidden_key")
      expect(result).to eq("[FILTERED]")
    end

    it "returns the value for normal settings" do
      SiteSetting.title = "Test Forum"
      expect(sandbox.eval("$site_settings.title")).to eq("Test Forum")
    end
  end

  describe "private node names" do
    it "returns empty object for underscore-prefixed node names" do
      context = { "_internal" => [{ "json" => { "secret" => "data" } }] }
      private_sandbox = described_class.new(context, vars: {})

      result = private_sandbox.eval("$('_internal').item")
      expect(result).to eq({ "json" => {} })
    ensure
      private_sandbox&.dispose
    end

    it "returns node data for normal names" do
      context = { "My Node" => [{ "json" => { "value" => 123 } }] }
      named_sandbox = described_class.new(context, vars: {})

      result = named_sandbox.eval("$('My Node').first()")
      expect(result).to eq({ "json" => { "value" => 123 } })
    ensure
      named_sandbox&.dispose
    end
  end

  describe "current user exposure" do
    it "only exposes schema-declared fields" do
      result = sandbox.eval("JSON.stringify(Object.keys($current_user).sort())")
      keys = JSON.parse(result)
      expect(keys).to contain_exactly("id", "username")
    end

    it "populates user fields correctly" do
      expect(sandbox.eval("$current_user.id")).to eq(user.id)
      expect(sandbox.eval("$current_user.username")).to eq(user.username)
    end

    it "returns empty object when no user is provided" do
      no_user_sandbox = described_class.new(workflow_context, vars: vars)
      expect(no_user_sandbox.eval("JSON.stringify($current_user)")).to eq("{}")
    ensure
      no_user_sandbox&.dispose
    end
  end

  describe "$execution exposure" do
    it "exposes execution variables from workflow context" do
      context = { "__execution" => { "id" => 42, "workflow_name" => "My Workflow" } }
      exec_sandbox = described_class.new(context, vars: {})

      expect(exec_sandbox.eval("$execution.id")).to eq(42)
      expect(exec_sandbox.eval("$execution.workflow_name")).to eq("My Workflow")
    ensure
      exec_sandbox&.dispose
    end

    it "defaults to empty object when no execution context" do
      expect(sandbox.eval("JSON.stringify($execution)")).to eq("{}")
    end
  end

  describe "console capture" do
    it "captures log messages when enabled" do
      capturing_sandbox =
        described_class.new(workflow_context, user: user, vars: vars, capture_logs: true)

      capturing_sandbox.eval('console.log("hello")')
      capturing_sandbox.eval('console.warn("careful")')
      capturing_sandbox.eval('console.error("boom")')

      entries = capturing_sandbox.log.as_json
      expect(entries.map { |e| e["message"] }).to eq(%w[hello careful boom])
      expect(entries.map { |e| e["level"] }).to eq(%w[info warn error])
    ensure
      capturing_sandbox&.dispose
    end
  end

  describe "workflow budget" do
    it "shares elapsed sandbox time through workflow context" do
      budget_state = {}

      Process.stubs(:clock_gettime).returns(0.0)

      first_sandbox =
        described_class.new(
          workflow_context,
          user: user,
          vars: vars,
          budget_tracker: DiscourseWorkflows::SandboxBudget.new(budget_state, budget_ms: 100),
        )
      second_sandbox =
        described_class.new(
          workflow_context,
          user: user,
          vars: vars,
          budget_tracker: DiscourseWorkflows::SandboxBudget.new(budget_state, budget_ms: 100),
        )

      Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0.0, 0.06, 0.06, 0.12)

      first_sandbox.eval("1 + 1")

      expect { second_sandbox.eval("2 + 2") }.to raise_error(
        described_class::BudgetExceededError,
        /100ms/,
      )
      expect(budget_state[DiscourseWorkflows::SandboxBudget::CONTEXT_KEY]).to be > 100
    ensure
      first_sandbox&.dispose
      second_sandbox&.dispose
    end
  end

  describe "embedded JSON payloads" do
    it "rejects payloads larger than MAX_INJECTED_JSON_BYTES" do
      oversized_payload = { "data" => "x" * described_class::MAX_INJECTED_JSON_BYTES }

      expect { sandbox.declare_json("__huge", oversized_payload) }.to raise_error(
        described_class::PayloadTooLargeError,
        /__huge/,
      )
    end
  end
end
