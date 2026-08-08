# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::BadgeGranted::V1 do
  fab!(:user)
  fab!(:badge)
  fab!(:other_badge) { Fabricate(:badge, name: "Other badge") }

  describe ".load_options_context" do
    subject(:options) do
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "badges",
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    let(:filter) { nil }

    it "returns enabled badges for the chooser" do
      expect(options).to include(
        { id: badge.id, name: badge.name },
        { id: other_badge.id, name: other_badge.name },
      )
    end

    it "excludes disabled badges" do
      disabled_badge = Fabricate(:badge, name: "Disabled badge", enabled: false)

      expect(options).not_to include({ id: disabled_badge.id, name: disabled_badge.name })
    end

    context "with a filter term" do
      let(:filter) { "Other badge" }

      it "filters badges" do
        expect(options).to contain_exactly({ id: other_badge.id, name: other_badge.name })
      end
    end
  end

  describe "#valid?" do
    it "returns true when the badge and user exist" do
      expect(described_class.new(badge.id, user.id)).to be_valid
    end

    it "returns false when the badge is missing" do
      expect(described_class.new(nil, user.id)).not_to be_valid
    end

    it "returns false when the user is missing" do
      expect(described_class.new(badge.id, User.maximum(:id).to_i + 1)).not_to be_valid
    end
  end

  describe "#output" do
    it "returns the user and badge payloads", :aggregate_failures do
      output = described_class.new(badge.id, user.id).output

      expect(output[:user]).to include(id: user.id, username: user.username)
      expect(output[:badge]).to include(
        id: badge.id,
        name: badge.name,
        badge_type_id: badge.badge_type_id,
        icon: badge.icon,
        grant_count: badge.grant_count,
        system: false,
        multiple_grant: false,
      )
      expect(output).to match_node_output_schema(described_class)
    end
  end

  describe "#matches?" do
    it "matches any badge when badge_id is blank" do
      trigger = described_class.new(badge.id, user.id)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
    end

    it "matches only the configured badge" do
      trigger = described_class.new(badge.id, user.id)

      expect(trigger.matches?(trigger_context("badge_id" => badge.id.to_s))).to eq(true)
      expect(trigger.matches?(trigger_context("badge_id" => other_badge.id.to_s))).to eq(false)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
