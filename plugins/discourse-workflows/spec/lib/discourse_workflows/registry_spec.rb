# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  before do
    described_class.reset_indexes!
  end

  describe ".triggers" do
    it "returns registered triggers from the plugin registry" do
      expect(described_class.triggers).to be_present
      expect(described_class.triggers.all? { |t| t.respond_to?(:identifier) }).to be(true)
    end
  end

  describe ".actions" do
    it "returns registered actions from the plugin registry" do
      expect(described_class.actions).to be_present
      expect(described_class.actions.all? { |a| a.respond_to?(:identifier) }).to be(true)
    end
  end

  describe ".conditions" do
    it "returns registered conditions from the plugin registry" do
      expect(described_class.conditions).to be_present
      expect(described_class.conditions.all? { |c| c.respond_to?(:identifier) }).to be(true)
    end
  end

  describe ".find_node_type" do
    it "finds a registered node type by identifier" do
      trigger = described_class.triggers.first
      expect(described_class.find_node_type(trigger.identifier)).to eq(trigger)
    end

    it "returns nil for unknown identifiers" do
      expect(described_class.find_node_type("trigger:nonexistent")).to be_nil
    end
  end
end
