# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  before do
    SiteSetting.discourse_workflows_enabled = true
    described_class.reset!
  end

  after { described_class.reset! }

  describe ".register_trigger" do
    it "registers a trigger class" do
      stub_class = Class.new { def self.identifier = "trigger:test" }
      described_class.register_trigger(stub_class)
      expect(described_class.triggers).to include(stub_class)
    end
  end

  describe ".register_action" do
    it "registers an action class" do
      stub_class = Class.new { def self.identifier = "action:test" }
      described_class.register_action(stub_class)
      expect(described_class.actions).to include(stub_class)
    end
  end

  describe ".register_condition" do
    it "registers a condition class" do
      stub_class = Class.new { def self.identifier = "condition:test" }
      described_class.register_condition(stub_class)
      expect(described_class.conditions).to include(stub_class)
    end
  end

  describe ".find_node_type" do
    it "finds a registered node type by identifier" do
      stub_class = Class.new { def self.identifier = "trigger:test" }
      described_class.register_trigger(stub_class)
      expect(described_class.find_node_type("trigger:test")).to eq(stub_class)
    end

    it "returns nil for unknown identifiers" do
      expect(described_class.find_node_type("trigger:nonexistent")).to be_nil
    end
  end
end
