# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserUpdated::V1 do
  fab!(:user)
  fab!(:group) { Fabricate(:group, name: "workflow_updated_grp") }
  fab!(:other_group) { Fabricate(:group, name: "workflow_other_grp") }

  describe ".load_options_context" do
    def load_options(filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "groups",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    it "returns groups for the chooser" do
      expect(load_options).to include(
        { id: group.id, name: group.name },
        { id: other_group.id, name: other_group.name },
      )
    end

    it "filters groups by the filter term" do
      expect(load_options(filter: group.name)).to contain_exactly(
        { id: group.id, name: group.name },
      )
    end
  end

  describe "#valid?" do
    it "returns true for a human user" do
      expect(described_class.new(user)).to be_valid
    end

    it "returns false when the user is missing" do
      expect(described_class.new(nil)).not_to be_valid
    end

    it "returns false for bot users" do
      expect(described_class.new(Discourse.system_user)).not_to be_valid
    end
  end

  describe "#user_id" do
    it "returns the updated user ID" do
      expect(described_class.new(user).user_id).to eq(user.id)
    end
  end

  describe "#output" do
    it "returns the user payload", :aggregate_failures do
      output = described_class.new(user).output

      expect(output[:user]).to include(
        id: user.id,
        username: user.username,
        trust_level: user.trust_level,
        staged: false,
        created_at: user.created_at.iso8601,
      )
      expect(output).to match_node_output_schema(described_class)
    end

    it "exposes the avatar so vision triage can reach it", :aggregate_failures do
      avatar = Fabricate(:upload)
      user.update!(uploaded_avatar_id: avatar.id)

      output = described_class.new(user).output

      expect(output.dig(:user, :uploaded_avatar_id)).to eq(avatar.id)
      expect(output.dig(:user, :avatar_template)).to include(avatar.id.to_s)
    end
  end

  describe "#matches?" do
    it "matches regular and staged users by default" do
      staged_user = Fabricate(:user, staged: true)

      expect(described_class.new(user).matches?(trigger_context({}))).to eq(true)
      expect(described_class.new(staged_user).matches?(trigger_context({}))).to eq(true)
    end

    it "matches only users in the selected groups" do
      group.add(user)

      expect(
        described_class.new(user).matches?(trigger_context("group_ids" => [group.id.to_s])),
      ).to eq(true)
      expect(
        described_class.new(user).matches?(trigger_context("group_ids" => [other_group.id.to_s])),
      ).to eq(false)
    end

    it "does not match malformed group filters" do
      expect(described_class.new(user).matches?(trigger_context("group_ids" => ["bogus"]))).to eq(
        false,
      )
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
