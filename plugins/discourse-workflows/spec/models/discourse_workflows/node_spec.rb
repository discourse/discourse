# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseWorkflows::Node do
  before do
    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::Schedule::V1)
  end

  after { DiscourseWorkflows::Registry.reset! }

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
        I18n.t("discourse_workflows.errors.invalid_cron_expression"),
      )
    end
  end
end
