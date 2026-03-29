# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::Group::V1 do
  fab!(:user)
  fab!(:group)
  fab!(:group_2) { Fabricate(:group, name: "another_group") }

  before { SiteSetting.discourse_workflows_enabled = true }

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

  describe "#execute_single" do
    let(:action) { described_class.new(configuration: {}) }
    let(:item) { { "json" => {} } }

    context "with add operation" do
      it "adds the user to the group" do
        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        result = action.execute_single({}, item: item, config: config)

        expect(result[:user_id]).to eq(user.id)
        expect(result[:username]).to eq(user.username)
        expect(result[:group_id]).to eq(group.id)
        expect(result[:group_name]).to eq(group.name)
        expect(GroupUser.exists?(user: user, group: group)).to eq(true)
      end

      it "is idempotent when user is already a member" do
        group.add(user)

        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        expect { action.execute_single({}, item: item, config: config) }.not_to change {
          GroupUser.where(user: user, group: group).count
        }
      end

      it "logs the action in group history" do
        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        expect { action.execute_single({}, item: item, config: config) }.to change {
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

        result = action.execute_single({}, item: item, config: config)

        expect(result[:user_id]).to eq(user.id)
        expect(result[:username]).to eq(user.username)
        expect(result[:group_id]).to eq(group.id)
        expect(result[:group_name]).to eq(group.name)
        expect(GroupUser.exists?(user: user, group: group)).to eq(false)
      end

      it "logs the removal in group history" do
        group.add(user)

        config = {
          "operation" => "remove",
          "username" => user.username,
          "group_id" => group.id.to_s,
        }

        expect { action.execute_single({}, item: item, config: config) }.to change {
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

      expect { action.execute_single({}, item: item, config: config) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "raises when group does not exist" do
      config = { "operation" => "add", "username" => user.username, "group_id" => "-1" }

      expect { action.execute_single({}, item: item, config: config) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "uses run_as_user for group action logging" do
      run_as = Fabricate(:admin)
      action.instance_variable_set(:@run_as_user, run_as)

      config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

      action.execute_single({}, item: item, config: config)

      expect(
        GroupHistory.find_by(
          group: group,
          target_user: user,
          action: GroupHistory.actions[:add_user_to_group],
        ).acting_user_id,
      ).to eq(run_as.id)
    end
  end
end
