# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Group::V1 do
  fab!(:user)
  fab!(:admin)
  fab!(:group)
  fab!(:group_2) { Fabricate(:group, name: "another_group") }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("action:group")
    end
  end

  describe ".metadata" do
    it "returns non-automatic groups for the chooser" do
      expect(described_class.metadata[:groups]).to include(
        { id: group.id, name: group.name },
        { id: group_2.id, name: group_2.name },
      )
    end

    it "excludes automatic groups" do
      auto_group_ids = described_class.metadata[:groups].map { |g| g[:id] }
      expect(auto_group_ids).not_to include(*Group::AUTO_GROUP_IDS.values)
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

    context "with add operation" do
      it "adds the user to the group" do
        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        result = execute_node(configuration: config, item: item)

        expect(result["user_id"]).to eq(user.id)
        expect(result["username"]).to eq(user.username)
        expect(result["group_id"]).to eq(group.id)
        expect(result["group_name"]).to eq(group.name)
        expect(GroupUser.exists?(user: user, group: group)).to be(true)
      end

      it "is idempotent when user is already a member" do
        group.add(user)

        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        expect { execute_node(configuration: config, item: item) }.not_to change {
          GroupUser.where(user: user, group: group).count
        }
      end

      it "logs the action in group history" do
        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        expect { execute_node(configuration: config, item: item) }.to change {
          GroupHistory.where(
            group: group,
            target_user: user,
            action: GroupHistory.actions[:add_user_to_group],
          ).count
        }.by(1)
      end
    end

    context "with remove operation" do
      it "removes the user from the group" do
        group.add(user)

        config = {
          "operation" => "remove",
          "username" => user.username,
          "group_id" => group.id.to_s,
        }

        result = execute_node(configuration: config, item: item)

        expect(result["user_id"]).to eq(user.id)
        expect(result["username"]).to eq(user.username)
        expect(result["group_id"]).to eq(group.id)
        expect(result["group_name"]).to eq(group.name)
        expect(GroupUser.exists?(user: user, group: group)).to be(false)
      end

      it "logs the removal in group history" do
        group.add(user)

        config = {
          "operation" => "remove",
          "username" => user.username,
          "group_id" => group.id.to_s,
        }

        expect { execute_node(configuration: config, item: item) }.to change {
          GroupHistory.where(
            group: group,
            target_user: user,
            action: GroupHistory.actions[:remove_user_from_group],
          ).count
        }.by(1)
      end
    end

    it "raises when user does not exist" do
      config = {
        "operation" => "add",
        "username" => "nonexistent_user",
        "group_id" => group.id.to_s,
      }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises when group does not exist" do
      config = { "operation" => "add", "username" => user.username, "group_id" => "-1" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "uses run_as_user for group action logging" do
      config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

      execute_node(configuration: config, item: item, run_as_user: admin)

      expect(
        GroupHistory.find_by(
          group: group,
          target_user: user,
          action: GroupHistory.actions[:add_user_to_group],
        ).acting_user_id,
      ).to eq(admin.id)
    end

    context "with get operation" do
      it "returns group data" do
        config = { "operation" => "get", "group_id" => group.id.to_s }

        result = execute_node(configuration: config, item: item)

        expect(result["group"]["id"]).to eq(group.id)
        expect(result["group"]["name"]).to eq(group.name)
        expect(result["group"]["user_count"]).to eq(group.user_count)
        expect(result["group"]["automatic"]).to be(false)
      end

      it "raises when group does not exist" do
        config = { "operation" => "get", "group_id" => "-1" }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          ActiveRecord::RecordNotFound,
        )
      end
    end
  end
end
