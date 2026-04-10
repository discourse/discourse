# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Badge::V1 do
  fab!(:user)
  fab!(:admin)
  fab!(:badge)
  fab!(:badge_2) { Fabricate(:badge, name: "A badge") }

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

  def execute_node(configuration:, item:, run_as_user: Discourse.system_user)
    action = described_class.new(configuration: configuration)
    input_items = [item]
    resolver = DiscourseWorkflows::ExpressionResolver.new({ "$json" => item.fetch("json") { {} } })
    exec_ctx =
      DiscourseWorkflows::NodeExecutionContext.new(
        input_items: input_items,
        run_as_user: run_as_user,
        resolver: resolver,
        configuration: configuration,
        configuration_schema: described_class.configuration_schema,
      )
    items = action.execute(exec_ctx)[0]
    items.first["json"]
  end

  describe "#execute" do
    let(:item) { { "json" => {} } }

    context "with grant operation" do
      it "grants the badge to the user" do
        config = {
          "operation" => "grant",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        result = execute_node(configuration: config, item: item)

        expect(result["user_id"]).to eq(user.id)
        expect(result["username"]).to eq(user.username)
        expect(result["badge_id"]).to eq(badge.id)
        expect(result["badge_name"]).to eq(badge.name)
        expect(UserBadge.exists?(user: user, badge: badge)).to be(true)
      end

      it "does not duplicate a non-multiple-grant badge" do
        BadgeGranter.grant(badge, user, granted_by: Discourse.system_user)

        config = {
          "operation" => "grant",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        expect { execute_node(configuration: config, item: item) }.not_to change {
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

        execute_node(configuration: config, item: item)

        expect(UserBadge.exists?(user: user, badge: badge)).to be(false)
      end

      it "is idempotent when user does not have the badge" do
        config = {
          "operation" => "revoke",
          "username" => user.username,
          "badge_id" => badge.id.to_s,
        }

        expect { execute_node(configuration: config, item: item) }.not_to raise_error
      end
    end

    it "raises when user does not exist" do
      config = {
        "operation" => "grant",
        "username" => "nonexistent_user",
        "badge_id" => badge.id.to_s,
      }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises when badge does not exist" do
      config = { "operation" => "grant", "username" => user.username, "badge_id" => "-1" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "uses run_as_user when granting" do
      config = { "operation" => "grant", "username" => user.username, "badge_id" => badge.id.to_s }

      execute_node(configuration: config, item: item, run_as_user: admin)

      expect(UserBadge.find_by(user: user, badge: badge).granted_by_id).to eq(admin.id)
    end

    it "uses run_as_user when revoking" do
      BadgeGranter.grant(badge, user, granted_by: Discourse.system_user)

      config = { "operation" => "revoke", "username" => user.username, "badge_id" => badge.id.to_s }

      execute_node(configuration: config, item: item, run_as_user: admin)

      expect(UserBadge.exists?(user: user, badge: badge)).to be(false)
    end

    it "defaults to system user when run_as_user is not set" do
      config = { "operation" => "grant", "username" => user.username, "badge_id" => badge.id.to_s }

      execute_node(configuration: config, item: item)

      expect(UserBadge.find_by(user: user, badge: badge).granted_by_id).to eq(
        Discourse.system_user.id,
      )
    end
  end
end
