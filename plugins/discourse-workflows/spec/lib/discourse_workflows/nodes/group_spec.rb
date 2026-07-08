# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Group::V1 do
  fab!(:user)
  fab!(:admin)
  fab!(:group)
  fab!(:group_2) { Fabricate(:group, name: "another_group") }

  describe ".load_options_context" do
    def load_options(parameters: {}, filter: nil)
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "groups",
          parameters: parameters,
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    it "returns groups for the chooser", :aggregate_failures do
      options = load_options

      expect(options).to include(
        { id: group.id, name: group.name },
        { id: group_2.id, name: group_2.name },
      )

      option_ids = options.map { |option| option[:id] }
      expect(option_ids).to include(*Group::AUTO_GROUPS.values)
    end

    it "filters groups by the filter term" do
      expect(load_options(filter: "another")).to contain_exactly(
        { id: group_2.id, name: group_2.name },
      )
    end
  end

  describe "#execute" do
    let(:item) { { "json" => {} } }

    context "with add operation" do
      it "adds the user to the group" do
        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        result = execute_node(configuration: config, item: item)

        expect(result["group"]["id"]).to eq(group.id)
        expect(result["group"]["name"]).to eq(group.name)
        expect(result["user"]["id"]).to eq(user.id)
        expect(result["user"]["username"]).to eq(user.username)
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

      it "raises when actor_username cannot edit the group" do
        config = {
          "operation" => "add",
          "username" => user.username,
          "group_id" => group.id.to_s,
          "actor_username" => user.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          Discourse::InvalidAccess,
        )
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

        expect(result["group"]["id"]).to eq(group.id)
        expect(result["group"]["name"]).to eq(group.name)
        expect(result["user"]["id"]).to eq(user.id)
        expect(result["user"]["username"]).to eq(user.username)
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

      it "raises when actor_username cannot edit the group" do
        config = {
          "operation" => "remove",
          "username" => user.username,
          "group_id" => group.id.to_s,
          "actor_username" => user.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          Discourse::InvalidAccess,
        )
      end
    end

    it "raises when user does not exist" do
      config = {
        "operation" => "add",
        "username" => "nonexistent_user",
        "group_id" => group.id.to_s,
      }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        DiscourseWorkflows::NodeError,
        "User 'nonexistent_user' not found",
      )
    end

    it "raises when group does not exist" do
      config = { "operation" => "add", "username" => user.username, "group_id" => "-1" }

      expect { execute_node(configuration: config, item: item) }.to raise_error(
        ActiveRecord::RecordNotFound,
      )
    end

    it "uses actor_username for group action logging" do
      config = {
        "operation" => "add",
        "username" => user.username,
        "group_id" => group.id.to_s,
        "actor_username" => admin.username,
      }

      execute_node(configuration: config, item: item)

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

      it "raises when actor_username cannot see the group" do
        group.update!(visibility_level: Group.visibility_levels[:staff])
        config = {
          "operation" => "get",
          "group_id" => group.id.to_s,
          "actor_username" => user.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          Discourse::InvalidAccess,
        )
      end
    end

    context "with check_membership operation" do
      fab!(:member, :user)
      fab!(:non_member, :user)

      before { group.add(member) }

      it "adds membership data to each item", :aggregate_failures do
        output =
          execute_node_output(
            configuration: {
              "operation" => "check_membership",
              "username" => "={{ $json.username }}",
              "group_id" => group.id,
              "actor_username" => "system",
            },
            input_items: [
              { "json" => { "username" => member.username, "post_id" => 1 } },
              { "json" => { "username" => non_member.username, "post_id" => 2 } },
            ],
          )

        expect(output.first.map { |item| item["json"] }).to contain_exactly(
          include(
            "username" => member.username,
            "post_id" => 1,
            "group_membership" =>
              include(
                "group_id" => group.id,
                "group_name" => group.name,
                "user_id" => member.id,
                "username" => member.username,
                "in_group" => true,
              ),
          ),
          include(
            "username" => non_member.username,
            "post_id" => 2,
            "group_membership" =>
              include(
                "group_id" => group.id,
                "group_name" => group.name,
                "user_id" => non_member.id,
                "username" => non_member.username,
                "in_group" => false,
              ),
          ),
        )
      end

      it "handles the logged_in_users pseudogroup without group_users rows", :aggregate_failures do
        logged_in_users = Group.refresh_automatic_group!(:logged_in_users)
        GroupUser.where(group: logged_in_users, user: member).delete_all

        output =
          execute_node_output(
            configuration: {
              "operation" => "check_membership",
              "username" => member.username,
              "group_id" => logged_in_users.id,
              "actor_username" => "system",
            },
          )

        membership_data = output.first.first.dig("json", "group_membership")

        expect(membership_data).to include(
          "group_id" => logged_in_users.id,
          "group_name" => logged_in_users.name,
          "user_id" => member.id,
          "username" => member.username,
          "in_group" => true,
        )
        expect(GroupUser.exists?(group: logged_in_users, user: member)).to be(false)
      end

      it "raises when the user cannot be found" do
        expect do
          execute_node(
            configuration: {
              "operation" => "check_membership",
              "username" => "missing_user",
              "group_id" => group.id,
            },
          )
        end.to raise_error(DiscourseWorkflows::NodeError, "User 'missing_user' not found")
      end

      it "raises when actor_username cannot see the group" do
        group.update!(visibility_level: Group.visibility_levels[:staff])
        config = {
          "operation" => "check_membership",
          "username" => member.username,
          "group_id" => group.id.to_s,
          "actor_username" => user.username,
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(
          Discourse::InvalidAccess,
        )
      end
    end
  end
end
