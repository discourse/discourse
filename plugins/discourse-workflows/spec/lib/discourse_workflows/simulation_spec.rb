# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Simulation do
  describe DiscourseWorkflows::Simulation::Declaration do
    it "classifies operations by mode" do
      declaration =
        described_class.new do
          pure "get", "list"
          supported "create"
          recorded "request"
          unsupported "delete"
          lookup "get"
          fingerprint_except "body"
        end

      expect(declaration.mode_for("get")).to eq(:pure)
      expect(declaration.mode_for("create")).to eq(:supported)
      expect(declaration.mode_for("request")).to eq(:recorded)
      expect(declaration.mode_for("delete")).to be_nil
      expect(declaration.mode_for("unknown")).to be_nil
      expect(declaration.lookup?("get")).to be(true)
      expect(declaration.lookup?("list")).to be(false)
      expect(declaration.fingerprint_excluded).to eq(["body"])
      expect(declaration.declared_operations).to contain_exactly(
        "get",
        "list",
        "create",
        "request",
        "delete",
      )
    end

    it "applies an operation-less mode to every operation" do
      declaration = described_class.new { pure }

      expect(declaration.single_mode?).to be(true)
      expect(declaration.mode_for(nil)).to eq(:pure)
      expect(declaration.mode_for("anything")).to eq(:pure)
    end

    it "treats an operation-less unsupported declaration as unclassified" do
      declaration = described_class.new { unsupported }

      expect(declaration.mode_for(nil)).to be_nil
    end

    it "rejects classifying an operation twice" do
      expect {
        described_class.new do
          pure "get"
          supported "get"
        end
      }.to raise_error(ArgumentError, /already classified/)
    end
  end

  describe DiscourseWorkflows::Simulation::SafetyError do
    it "carries a reason key and params and renders a message" do
      error = described_class.new(:unsupported_step, step: "Send PM")

      expect(error.reason_key).to eq("unsupported_step")
      expect(error.params).to eq(step: "Send PM")
      expect(error.message).to include("Send PM")
    end
  end
end
