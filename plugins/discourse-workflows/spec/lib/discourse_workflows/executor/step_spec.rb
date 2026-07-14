# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::Step do
  let(:node) { Struct.new(:id, :name, :type).new("abc-123", "My Node", "action:code") }

  describe ".build" do
    it "creates a running step with required fields" do
      step = described_class.build(node: node, position: 0, input: [])

      expect(step.node_id).to eq("abc-123")
      expect(step.node_name).to eq("My Node")
      expect(step.node_type).to eq("action:code")
      expect(step.position).to eq(0)
      expect(step).to be_running
      expect(step.input).to eq([])
      expect(step.started_at).to be_present
      expect(step.finished_at).to be_nil
      expect(step.output).to be_nil
      expect(step.error).to be_nil
    end

    it "includes finished_at for non-running statuses" do
      step =
        described_class.build(node: node, position: 1, input: [], status: "success", output: [])

      expect(step).to be_success
      expect(step.finished_at).to be_present
      expect(step.output).to eq([])
    end

    it "includes error when provided" do
      step =
        described_class.build(
          node: node,
          position: 2,
          input: [],
          status: "error",
          error: "something broke",
        )

      expect(step.error).to eq("something broke")
    end

    it "includes metadata when provided" do
      step =
        described_class.build(
          node: node,
          position: 0,
          input: [],
          metadata: {
            "resolved_configuration" => {
              "key" => "val",
            },
          },
        )

      expect(step.metadata).to eq("resolved_configuration" => { "key" => "val" })
    end
  end

  describe "timestamp precision" do
    it "stores timestamps with millisecond precision" do
      step = described_class.build(node: node, position: 0, input: [])
      expect(step.started_at).to match(/\.\d{3}/)

      step.succeed!(output: [])
      expect(step.finished_at).to match(/\.\d{3}/)
    end
  end

  describe "status transitions" do
    let(:step) { described_class.build(node: node, position: 0, input: []) }

    it "#succeed! transitions to success with output" do
      step.succeed!(output: [{ "json" => { "result" => true } }])

      expect(step).to be_success
      expect(step.output).to eq([{ "json" => { "result" => true } }])
      expect(step.finished_at).to be_present
    end

    it "#filter! transitions to filtered with output" do
      step.filter!(output: { "true" => [], "false" => [{ "json" => {} }] })

      expect(step).to be_filtered
      expect(step.output).to be_present
      expect(step.finished_at).to be_present
    end

    it "#fail! transitions to error with message" do
      step.fail!("something broke")

      expect(step).to be_error
      expect(step.error).to eq("something broke")
      expect(step.finished_at).to be_present
    end

    it "#mark_waiting! transitions to waiting without finishing" do
      step.mark_waiting!

      expect(step).to be_waiting
      expect(step.finished_at).to be_nil
    end
  end

  describe "#add_metadata" do
    it "initializes metadata hash and sets the key" do
      step = described_class.build(node: node, position: 0, input: [])
      step.add_metadata("logs", [{ "level" => "info" }])

      expect(step.metadata).to eq("logs" => [{ "level" => "info" }])
    end

    it "merges into existing metadata" do
      step = described_class.build(node: node, position: 0, input: [], metadata: { "a" => 1 })
      step.add_metadata("b", 2)

      expect(step.metadata).to eq("a" => 1, "b" => 2)
    end
  end

  describe "#apply_updates!" do
    it "applies hash updates to matching fields" do
      step = described_class.build(node: node, position: 0, input: [])
      step.mark_waiting!

      step.apply_updates!(
        "status" => "success",
        "output" => [{ "json" => {} }],
        "finished_at" => "2025-01-01T00:00:00Z",
      )

      expect(step).to be_success
      expect(step.output).to eq([{ "json" => {} }])
      expect(step.finished_at).to be_present
    end
  end

  describe "#to_h" do
    it "serializes to the expected hash format" do
      step = described_class.build(node: node, position: 0, input: [{ "json" => {} }])
      step.succeed!(output: [{ "json" => { "done" => true } }])
      step.add_metadata("logs", [])

      h = step.to_h

      expect(h["node_id"]).to eq("abc-123")
      expect(h["node_name"]).to eq("My Node")
      expect(h["node_type"]).to eq("action:code")
      expect(h["position"]).to eq(0)
      expect(h["status"]).to eq("success")
      expect(h["input"]).to eq([{ "json" => {} }])
      expect(h["output"]).to eq([{ "json" => { "done" => true } }])
      expect(h["started_at"]).to be_present
      expect(h["finished_at"]).to be_present
      expect(h["metadata"]).to eq("logs" => [])
      expect(h).not_to have_key("error")
    end

    it "omits nil optional fields" do
      step = described_class.build(node: node, position: 0, input: [])
      h = step.to_h

      expect(h).not_to have_key("output")
      expect(h).not_to have_key("finished_at")
      expect(h).not_to have_key("error")
      expect(h).not_to have_key("metadata")
    end
  end

  describe ".from_h" do
    it "round-trips through to_h" do
      original = described_class.build(node: node, position: 3, input: [{ "json" => {} }])
      original.succeed!(output: [{ "json" => { "x" => 1 } }])
      original.add_metadata("resolved_configuration", { "key" => "val" })

      restored = described_class.from_h(original.to_h)

      expect(restored.to_h).to eq(original.to_h)
    end
  end

  describe "SKIPPED status" do
    it "supports skip! transition" do
      step =
        described_class.new(
          node_id: "1",
          node_name: "Test",
          node_type: "action:test",
          position: 0,
          input: [],
        )

      step.skip!(output: [{ "json" => { "a" => 1 } }], reason: "Node unavailable")

      expect(step.status).to eq("skipped")
      expect(step.output).to eq([{ "json" => { "a" => 1 } }])
      expect(step.error).to eq("Node unavailable")
      expect(step.finished_at).to be_present
    end

    it "responds to skipped?" do
      step =
        described_class.new(
          node_id: "1",
          node_name: "Test",
          node_type: "action:test",
          position: 0,
          input: [],
          status: described_class::SKIPPED,
        )

      expect(step).to be_skipped
    end
  end
end
