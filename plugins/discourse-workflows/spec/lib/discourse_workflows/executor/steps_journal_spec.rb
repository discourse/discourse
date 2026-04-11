# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::StepsJournal do
  let(:journal) { described_class.new }

  def build_step(node_id:, status: "running", position: 0, node_type: "action:code", **kwargs)
    DiscourseWorkflows::Executor::Step.new(
      node_id: node_id,
      node_name: "Node #{node_id}",
      node_type: node_type,
      position: position,
      input: [],
      status: status,
      **kwargs,
    )
  end

  describe "#next_step_position" do
    it "increments monotonically" do
      expect(journal.next_step_position).to eq(0)
      expect(journal.next_step_position).to eq(1)
      expect(journal.next_step_position).to eq(2)
    end
  end

  describe "#record_step" do
    it "records steps under the given node name" do
      step = build_step(node_id: "1", status: "success")

      journal.record_step("my_node", step)

      expect(journal.entries["my_node"]).to eq([step.to_h])
    end

    it "appends multiple steps for the same node" do
      step_1 = build_step(node_id: "1", status: "running")
      step_2 = build_step(node_id: "1", status: "success", position: 1)

      journal.record_step("my_node", step_1)
      journal.record_step("my_node", step_2)

      expect(journal.steps).to eq([step_1, step_2])
    end

    it "coerces serialized hashes into steps" do
      journal.record_step(
        "my_node",
        {
          "node_id" => "1",
          "node_name" => "My node",
          "node_type" => "action:code",
          "position" => 0,
          "input" => [],
          "status" => "success",
        },
      )

      expect(journal.find_step(node_id: "1")).to be_a(DiscourseWorkflows::Executor::Step)
    end
  end

  describe "#find_step" do
    before do
      journal.record_step("node_a", build_step(node_id: "1", status: "running"))
      journal.record_step("node_a", build_step(node_id: "1", status: "success", position: 1))
      journal.record_step("node_b", build_step(node_id: "2", status: "success", position: 2))
    end

    it "finds a step by node id" do
      expect(journal.find_step(node_id: "2")&.node_id).to eq("2")
    end

    it "filters by status when provided" do
      found = journal.find_step(node_id: "1", status: "success")

      expect(found.node_id).to eq("1")
      expect(found).to be_success
    end

    it "returns nil when no step matches" do
      expect(journal.find_step(node_id: "999")).to be_nil
    end
  end

  describe "#update_step!" do
    it "updates a matching step in place" do
      step = build_step(node_id: "1", status: "waiting")
      journal.record_step("my_node", step)

      journal.update_step!(
        node_id: "1",
        from_status: "waiting",
        updates: {
          "status" => "success",
          "output" => [{ "json" => {} }],
        },
      )

      expect(step).to be_success
      expect(step.output).to eq([{ "json" => {} }])
    end

    it "returns nil when no matching step exists" do
      expect(journal.update_step!(node_id: "999", from_status: "waiting", updates: {})).to be_nil
    end
  end

  describe "#last_failed_step" do
    it "returns the last errored step" do
      journal.record_step("node_a", build_step(node_id: "1", status: "success"))
      journal.record_step("node_a", build_step(node_id: "2", status: "error", position: 1))
      journal.record_step("node_b", build_step(node_id: "3", status: "success", position: 2))

      expect(journal.last_failed_step&.node_id).to eq("2")
    end

    it "returns nil when there are no failures" do
      journal.record_step("node_a", build_step(node_id: "1", status: "success"))

      expect(journal.last_failed_step).to be_nil
    end
  end

  describe "#restore!" do
    it "defaults the next position to the total restored steps" do
      journal.restore!(
        entries: {
          "node_a" => [build_step(node_id: "1", position: 0).to_h],
          "node_b" => [build_step(node_id: "2", position: 1).to_h],
        },
      )

      expect(journal.next_step_position).to eq(2)
    end
  end

  describe "#total_steps" do
    it "returns 0 when empty" do
      expect(journal.total_steps).to eq(0)
    end

    it "counts all steps across nodes" do
      journal.record_step("node_a", build_step(node_id: "1"))
      journal.record_step("node_a", build_step(node_id: "1", position: 1))
      journal.record_step("node_b", build_step(node_id: "2", position: 2))

      expect(journal.total_steps).to eq(3)
    end
  end

  describe "#entries" do
    it "serializes steps to hashes" do
      journal.record_step("node_a", build_step(node_id: "1", status: "success"))

      data = journal.entries

      expect(data["node_a"].first).to include("node_id" => "1", "status" => "success")
    end
  end

  describe "#find_steps_by_type" do
    it "returns only steps matching the requested type" do
      journal.record_step("node_a", build_step(node_id: "1", status: "success"))
      journal.record_step(
        "node_b",
        build_step(node_id: "2", status: "success", position: 1, node_type: "action:http"),
      )

      expect(journal.find_steps_by_type("action:http").map(&:node_id)).to eq(["2"])
    end
  end

  describe "#serialized_steps_array" do
    it "returns steps ordered by position" do
      journal.record_step("node_a", build_step(node_id: "1", position: 2))
      journal.record_step("node_b", build_step(node_id: "2", position: 1))

      expect(journal.serialized_steps_array.map { |step| step["node_id"] }).to eq(%w[2 1])
    end
  end
end
