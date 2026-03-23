# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::AwardBadge::V1 do
  fab!(:user)
  fab!(:badge)

  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:award_badge")
    end
  end

  describe "#execute_single" do
    let(:action) { described_class.new(configuration: {}) }
    let(:item) { { "json" => {} } }

    it "grants the badge to the user" do
      config = { "user_id" => user.id.to_s, "badge_id" => badge.id.to_s }

      result = action.execute_single({}, item: item, config: config)

      expect(result[:user_id]).to eq(user.id)
      expect(result[:username]).to eq(user.username)
      expect(result[:badge_id]).to eq(badge.id)
      expect(result[:badge_name]).to eq(badge.name)
      expect(UserBadge.exists?(user: user, badge: badge)).to eq(true)
    end

    it "does not duplicate a non-multiple-grant badge" do
      BadgeGranter.grant(badge, user, granted_by: Discourse.system_user)

      config = { "user_id" => user.id.to_s, "badge_id" => badge.id.to_s }

      expect { action.execute_single({}, item: item, config: config) }.not_to change {
        UserBadge.where(user: user, badge: badge).count
      }
    end

    it "raises when user does not exist" do
      config = { "user_id" => "0", "badge_id" => badge.id.to_s }

      expect { action.execute_single({}, item: item, config: config) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises when badge does not exist" do
      config = { "user_id" => user.id.to_s, "badge_id" => "-1" }

      expect { action.execute_single({}, item: item, config: config) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end
  end
end
