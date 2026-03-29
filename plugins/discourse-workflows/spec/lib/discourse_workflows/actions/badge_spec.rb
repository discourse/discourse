# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::Badge::V1 do
  fab!(:user)
  fab!(:badge)
  fab!(:badge_2) { Fabricate(:badge, name: "A badge") }

  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:badge")
    end
  end

  describe ".metadata" do
    it "returns badges for the chooser" do
      expect(described_class.metadata[:badges]).to include(
        { id: badge_2.id, name: badge_2.name },
        { id: badge.id, name: badge.name },
      )
    end
  end

  describe "#execute_single" do
    let(:action) { described_class.new(configuration: {}) }
    let(:item) { { "json" => {} } }

    context "with grant operation" do
      it "grants the badge to the user" do
        config = {
          "operation" => "grant",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        result = action.execute_single({}, item: item, config: config)

        expect(result[:user_id]).to eq(user.id)
        expect(result[:username]).to eq(user.username)
        expect(result[:badge_id]).to eq(badge.id)
        expect(result[:badge_name]).to eq(badge.name)
        expect(UserBadge.exists?(user: user, badge: badge)).to eq(true)
      end

      it "does not duplicate a non-multiple-grant badge" do
        BadgeGranter.grant(badge, user, granted_by: Discourse.system_user)

        config = {
          "operation" => "grant",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        expect { action.execute_single({}, item: item, config: config) }.not_to change {
          UserBadge.where(user: user, badge: badge).count
        }
      end
    end

    context "with revoke operation" do
      it "revokes the badge from the user" do
        BadgeGranter.grant(badge, user, granted_by: Discourse.system_user)

        config = {
          "operation" => "revoke",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        action.execute_single({}, item: item, config: config)

        expect(UserBadge.exists?(user: user, badge: badge)).to eq(false)
      end

      it "is idempotent when user does not have the badge" do
        config = {
          "operation" => "revoke",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        expect { action.execute_single({}, item: item, config: config) }.not_to raise_error
      end
    end

    it "raises when user does not exist" do
      config = {
        "operation" => "grant",
        "username" => "nonexistent_user",
        "badge_id" => badge.id.to_s,
      }

      expect { action.execute_single({}, item: item, config: config) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises when badge does not exist" do
      config = { "operation" => "grant", "username" => user.username, "badge_id" => "-1" }

      expect { action.execute_single({}, item: item, config: config) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end
  end
end
