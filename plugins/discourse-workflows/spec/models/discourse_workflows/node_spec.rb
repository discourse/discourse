# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseWorkflows::Node do
  before do
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Schedule::V1)
  end

  after { DiscourseWorkflows::Registry.reset! }

  describe "#form_data_from" do
    fab!(:workflow, :discourse_workflows_workflow)

    it "coerces number fields to integers" do
      node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:form",
          name: "Form",
          configuration: {
            "form_fields" => [{ "field_label" => "Age", "field_type" => "number" }],
          },
        )

      expect(node.form_data_from("age" => "12")).to eq("age" => 12)
    end

    it "coerces number fields with decimals to floats" do
      node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:form",
          name: "Form",
          configuration: {
            "form_fields" => [{ "field_label" => "Price", "field_type" => "number" }],
          },
        )

      expect(node.form_data_from("price" => "9.99")).to eq("price" => 9.99)
    end

    it "coerces checkbox fields to booleans" do
      node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:form",
          name: "Form",
          configuration: {
            "form_fields" => [{ "field_label" => "Agree", "field_type" => "checkbox" }],
          },
        )

      expect(node.form_data_from("agree" => "true")).to eq("agree" => true)
      expect(node.form_data_from("agree" => "false")).to eq("agree" => false)
    end

    it "returns nil for blank number fields" do
      node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:form",
          name: "Form",
          configuration: {
            "form_fields" => [{ "field_label" => "Age", "field_type" => "number" }],
          },
        )

      expect(node.form_data_from("age" => "")).to eq("age" => nil)
    end

    it "leaves text fields as strings" do
      node =
        Fabricate(
          :discourse_workflows_node,
          workflow: workflow,
          type: "trigger:form",
          name: "Form",
          configuration: {
            "form_fields" => [{ "field_label" => "Name", "field_type" => "text" }],
          },
        )

      expect(node.form_data_from("name" => "joffrey")).to eq("name" => "joffrey")
    end
  end

  describe "schedule configuration validation" do
    it "accepts a valid cron expression" do
      node =
        Fabricate.build(
          :discourse_workflows_node,
          type: "trigger:schedule",
          name: "Schedule",
          configuration: {
            "cron" => "0 9 * * 1-5",
          },
        )

      expect(node).to be_valid
    end

    it "rejects an invalid cron expression" do
      node =
        Fabricate.build(
          :discourse_workflows_node,
          type: "trigger:schedule",
          name: "Schedule",
          configuration: {
            "cron" => "invalid",
          },
        )

      expect(node).not_to be_valid
      expect(node.errors.full_messages).to include(
        "Schedule: #{I18n.t("discourse_workflows.errors.invalid_cron_expression")}",
      )
    end
  end
end
