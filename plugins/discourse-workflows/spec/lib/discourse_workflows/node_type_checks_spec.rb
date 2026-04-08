# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseWorkflows::NodeTypeChecks do
  def build_node(type:)
    DiscourseWorkflows::WorkflowSnapshot::SnapshotNode.new(
      id: "1",
      type: type,
      type_version: "1.0",
      name: "test",
      position: {
        "x" => 0,
        "y" => 0,
      },
      configuration: {
      },
    )
  end

  describe "#trigger?" do
    it "returns true for trigger types" do
      expect(build_node(type: "trigger:post_created")).to be_trigger
    end

    it "returns false for non-trigger types" do
      expect(build_node(type: "action:create_post")).not_to be_trigger
    end

    it "returns false when type is nil" do
      expect(build_node(type: nil)).not_to be_trigger
    end
  end

  describe "#action?" do
    it "returns true for action types" do
      expect(build_node(type: "action:create_post")).to be_action
    end

    it "returns false for non-action types" do
      expect(build_node(type: "trigger:post_created")).not_to be_action
    end
  end

  describe "#condition?" do
    it "returns true for condition types" do
      expect(build_node(type: "condition:filter")).to be_condition
    end

    it "returns false for non-condition types" do
      expect(build_node(type: "action:create_post")).not_to be_condition
    end
  end

  describe "#core?" do
    it "returns true for core types" do
      expect(build_node(type: "core:wait")).to be_core
    end

    it "returns false for non-core types" do
      expect(build_node(type: "action:create_post")).not_to be_core
    end
  end
end
