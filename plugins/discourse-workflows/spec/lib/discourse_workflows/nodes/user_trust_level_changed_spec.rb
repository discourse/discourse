# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::UserTrustLevelChanged::V1 do
  fab!(:user)

  let(:old_level) { TrustLevel.levels[:basic] }
  let(:new_level) { TrustLevel.levels[:member] }
  let(:event_data) { { user_id: user.id, old_trust_level: old_level, new_trust_level: new_level } }

  describe "#valid?" do
    it "requires changed trust levels and a human user" do
      expect(described_class.new(event_data)).to be_valid
      expect(
        described_class.new(
          event_data.merge(old_trust_level: new_level, new_trust_level: old_level),
        ),
      ).to be_valid

      expect(described_class.new(event_data.merge(new_trust_level: old_level))).not_to be_valid
      expect(described_class.new(event_data.merge(user_id: nil))).not_to be_valid
      expect(
        described_class.new(event_data.merge(user_id: Discourse::SYSTEM_USER_ID)),
      ).not_to be_valid
    end
  end

  describe "#output" do
    it "returns the user, the trust levels and the actor", :aggregate_failures do
      admin = Fabricate(:admin)
      output = described_class.new(event_data.merge(acting_user: admin)).output

      expect(output[:user]).to include(id: user.id, username: user.username)
      expect(output).to include(old_trust_level: old_level, new_trust_level: new_level)
      expect(output[:actor]).to include(id: admin.id, username: admin.username)
      expect(output).to match_node_output_schema(described_class)
    end

    it "builds from the event Promotion fires" do
      user.update!(trust_level: old_level)
      event =
        DiscourseEvent.track(:user_promoted) { Promotion.new(user).change_trust_level!(new_level) }

      expect(described_class.new(*event[:params]).output[:actor]).to include(
        id: Discourse.system_user.id,
      )
    end
  end

  describe "#matches?" do
    it "filters both the previous and new trust levels" do
      trigger = described_class.new(event_data)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
      expect(
        trigger.matches?(
          trigger_context(
            "old_trust_levels" => [old_level.to_s],
            "new_trust_levels" => [new_level.to_s],
          ),
        ),
      ).to eq(true)
      expect(trigger.matches?(trigger_context("old_trust_levels" => [new_level]))).to eq(false)
      expect(trigger.matches?(trigger_context("new_trust_levels" => [old_level]))).to eq(false)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
