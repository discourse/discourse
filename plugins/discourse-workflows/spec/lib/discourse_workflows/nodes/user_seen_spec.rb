# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserSeen::V1 do
  fab!(:user)
  fab!(:group) { Fabricate(:group, name: "workflow_seen_group") }
  fab!(:other_group) { Fabricate(:group, name: "workflow_other_grp") }

  describe ".load_options_context" do
    subject(:options) do
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "groups",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    let(:filter) { nil }

    it "returns groups for the chooser" do
      expect(options).to include(
        { id: group.id, name: group.name },
        { id: other_group.id, name: other_group.name },
      )
    end

    context "with a filter term" do
      let(:filter) { group.name }

      it "filters groups" do
        expect(options).to contain_exactly({ id: group.id, name: group.name })
      end
    end
  end

  describe "#valid?" do
    it "returns true when user is present" do
      trigger = described_class.new(user)
      expect(trigger).to be_valid
    end

    it "returns false when user is nil" do
      trigger = described_class.new(nil)
      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns user data and first seen state" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)

      trigger = described_class.new(user)
      output = trigger.output

      expect(output[:user][:id]).to eq(user.id)
      expect(output[:user][:username]).to eq(user.username)
      expect(output[:seen][:first_seen]).to eq(true)
      expect(output[:seen][:current_seen_at]).to eq(seen_at.iso8601)
      expect(output[:seen][:previous_seen_at]).to eq(nil)
      expect(output[:seen][:seconds_since_previous_seen]).to eq(nil)
      expect(output).to match_node_output_schema(described_class)
    end

    it "returns previous seen data" do
      current_seen_at = Time.zone.now
      previous_seen_at = current_seen_at - 2.days
      user.update_columns(first_seen_at: 1.month.ago, last_seen_at: current_seen_at)

      output = described_class.new(user, previous_seen_at).output

      expect(output[:seen][:first_seen]).to eq(false)
      expect(output[:seen][:current_seen_at]).to eq(current_seen_at.iso8601)
      expect(output[:seen][:previous_seen_at]).to eq(previous_seen_at.iso8601)
      expect(output[:seen][:seconds_since_previous_seen]).to eq(2.days.to_i)
      expect(output).to match_node_output_schema(described_class)
    end
  end

  describe "#user_id" do
    it "returns the seen user ID" do
      expect(described_class.new(user).user_id).to eq(user.id)
    end
  end

  describe "#matches?" do
    it "matches first seen events by default" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)
      context = DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => {} })

      expect(described_class.new(user).matches?(context)).to eq(true)
    end

    it "does not match later seen events by default" do
      user.update_columns(first_seen_at: 2.days.ago, last_seen_at: Time.zone.now)
      context = DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => {} })

      expect(described_class.new(user, 2.hours.ago).matches?(context)).to eq(false)
    end

    it "matches only users in the selected groups" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)
      group.add(user)
      selected_group_context =
        DiscourseWorkflows::TriggerNodeContext.new(
          { "parameters" => { "group_ids" => [group.id.to_s] } },
        )
      other_group_context =
        DiscourseWorkflows::TriggerNodeContext.new(
          { "parameters" => { "group_ids" => [other_group.id.to_s] } },
        )

      expect(described_class.new(user).matches?(selected_group_context)).to eq(true)
      expect(described_class.new(user).matches?(other_group_context)).to eq(false)
    end

    it "does not match malformed group filters" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)
      context =
        DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => { "group_ids" => ["bogus"] } })

      expect(described_class.new(user).matches?(context)).to eq(false)
    end

    it "does not match first seen events when first seen is disabled" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)
      context =
        DiscourseWorkflows::TriggerNodeContext.new(
          { "parameters" => { "trigger_on_first_seen" => false } },
        )

      expect(described_class.new(user).matches?(context)).to eq(false)
    end

    it "matches returning users who have not been seen for more than the configured time" do
      user.update_columns(first_seen_at: 1.month.ago, last_seen_at: Time.zone.now)
      context =
        DiscourseWorkflows::TriggerNodeContext.new(
          {
            "parameters" => {
              "trigger_on_not_seen_for_more_than" => true,
              "not_seen_for_amount" => 1,
              "not_seen_for_unit" => "days",
            },
          },
        )

      expect(described_class.new(user, 2.days.ago).matches?(context)).to eq(true)
    end

    it "does not match returning users seen within the configured time" do
      user.update_columns(first_seen_at: 1.month.ago, last_seen_at: Time.zone.now)
      context =
        DiscourseWorkflows::TriggerNodeContext.new(
          {
            "parameters" => {
              "trigger_on_not_seen_for_more_than" => true,
              "not_seen_for_amount" => 1,
              "not_seen_for_unit" => "days",
            },
          },
        )

      expect(described_class.new(user, 2.hours.ago).matches?(context)).to eq(false)
    end

    it "does not match first seen events with only the not seen threshold enabled" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)
      context =
        DiscourseWorkflows::TriggerNodeContext.new(
          {
            "parameters" => {
              "trigger_on_first_seen" => false,
              "trigger_on_not_seen_for_more_than" => true,
              "not_seen_for_amount" => 1,
              "not_seen_for_unit" => "days",
            },
          },
        )

      expect(described_class.new(user).matches?(context)).to eq(false)
    end

    it "matches when either enabled condition matches" do
      user.update_columns(first_seen_at: 1.month.ago, last_seen_at: Time.zone.now)
      context =
        DiscourseWorkflows::TriggerNodeContext.new(
          {
            "parameters" => {
              "trigger_on_first_seen" => true,
              "trigger_on_not_seen_for_more_than" => true,
              "not_seen_for_amount" => 1,
              "not_seen_for_unit" => "days",
            },
          },
        )

      expect(described_class.new(user, 2.days.ago).matches?(context)).to eq(true)
    end

    it "does not match when no conditions are enabled" do
      seen_at = Time.zone.now
      user.update_columns(first_seen_at: seen_at, last_seen_at: seen_at)
      context =
        DiscourseWorkflows::TriggerNodeContext.new(
          {
            "parameters" => {
              "trigger_on_first_seen" => false,
              "trigger_on_not_seen_for_more_than" => false,
            },
          },
        )

      expect(described_class.new(user).matches?(context)).to eq(false)
    end
  end
end
