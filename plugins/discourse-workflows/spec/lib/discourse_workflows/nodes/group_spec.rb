# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::Group::V1 do
  fab!(:user)
  fab!(:admin)
  fab!(:group)
  fab!(:group_2) { Fabricate(:group, name: "another_group") }

  describe ".upgrade" do
    let(:membership_parameters) do
      { "username" => "={{ $json.user.username }}", "group_id" => 12, "actor_username" => "system" }
    end

    it "moves adding to Add user to group, keeping the primary group setting" do
      parameters = membership_parameters.merge("operation" => "add", "set_primary_group" => true)

      expect(described_class.upgrade(parameters)).to eq(
        type: "action:add_user_to_group",
        parameters: membership_parameters.merge("set_primary_group" => true),
      )
    end

    it "treats a node without an operation as adding" do
      expect(described_class.upgrade(membership_parameters)).to eq(
        type: "action:add_user_to_group",
        parameters: membership_parameters,
      )
    end

    it "moves removing to Remove user from group" do
      parameters =
        membership_parameters.merge("operation" => "remove", "set_primary_group" => false)

      expect(described_class.upgrade(parameters)).to eq(
        type: "action:remove_user_from_group",
        parameters: membership_parameters,
      )
    end

    it "moves reads to version 2.0 without the primary group setting", :aggregate_failures do
      %w[get check_membership].each do |operation|
        parameters = membership_parameters.merge("operation" => operation)

        expect(described_class.upgrade(parameters.merge("set_primary_group" => false))).to eq(
          type: "action:group",
          version: "2.0",
          parameters:,
        )
      end
    end

    it "leaves a node whose operation is an expression to be replaced by hand" do
      expect(described_class.upgrade("operation" => "={{ $json.operation }}")).to be_nil
    end

    it "upgrades a saved add node to Add user to group, keeping the node" do
      node = {
        "id" => "node-1",
        "type" => "action:group",
        "typeVersion" => "1.0",
        "name" => "Add helper",
        "position" => [100, 200],
        "parameters" => membership_parameters.merge("operation" => "add"),
      }

      result = DiscourseWorkflows::NodeUpgrader.call([node])

      expect(result.nodes.sole).to include(
        "id" => "node-1",
        "name" => "Add helper",
        "position" => [100, 200],
        "type" => "action:add_user_to_group",
        "typeVersion" => "1.0",
        "parameters" => membership_parameters,
      )
    end
  end

  describe ".load_options_context" do
    subject(:options) do
      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "groups",
          parameters: parameters,
          filter: filter,
          node_class: described_class,
        )

      described_class.load_options_context(context)
    end

    let(:parameters) { {} }
    let(:filter) { nil }

    it "returns groups for the chooser", :aggregate_failures do
      expect(options).to include(
        { id: group.id, name: group.name },
        { id: group_2.id, name: group_2.name },
      )

      option_ids = options.map { |option| option[:id] }
      expect(option_ids).to include(*Group::AUTO_GROUPS.values)
    end

    context "with a filter term" do
      let(:filter) { "another" }

      it "filters groups" do
        expect(options).to contain_exactly({ id: group_2.id, name: group_2.name })
      end
    end
  end

  describe ".output_schemas" do
    let(:input_schema) do
      {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "source" => {
            "type" => "string",
          },
        },
      }
    end

    it "advertises a concrete schema for each operation", :aggregate_failures do
      group_with_user = described_class::GROUP_ACTION_SCHEMA

      expect(
        described_class.output_schemas({ "operation" => "add" }, input_schemas: [input_schema]),
      ).to eq([group_with_user])
      expect(
        described_class.output_schemas({ "operation" => "remove" }, input_schemas: [input_schema]),
      ).to eq([group_with_user])
      expect(
        described_class.output_schemas({ "operation" => "get" }, input_schemas: [input_schema]),
      ).to eq([DiscourseWorkflows::Schema::GROUP_SCHEMA])
    end

    it "merges membership data over the input schema for check_membership", :aggregate_failures do
      schema =
        described_class.output_schemas(
          { "operation" => "check_membership" },
          input_schemas: [input_schema],
        ).first

      expect(schema.dig("properties", "source")).to eq("type" => "string")
      expect(schema.dig("properties", "group_membership", "properties")).to include("in_group")
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
        expect(result["user"]["trust_level"]).to eq(user.trust_level)
        expect(result["group"]["user_count"]).to eq(group.reload.user_count)
        expect(result["changed"]).to be(true)
        expect(GroupUser.exists?(user: user, group: group)).to be(true)
        expect(result).to match_node_output_schema(described_class, configuration: config)
      end

      it "returns the trust level granted by the group" do
        user.update!(trust_level: TrustLevel[0])
        group.update!(grant_trust_level: TrustLevel[2])
        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        result = execute_node(configuration: config, item: item)

        expect(result["user"]["trust_level"]).to eq(TrustLevel[2])
      end

      it "is idempotent when user is already a member" do
        group.add(user)

        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        result = nil
        expect { result = execute_node(configuration: config, item: item) }.not_to change {
          GroupUser.where(user: user, group: group).count
        }
        expect(result["changed"]).to be(false)
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

      it "does not change the primary group by default" do
        user.update!(primary_group: group_2)
        group_2.add(user)

        config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

        execute_node(configuration: config, item: item)

        expect(user.reload.primary_group_id).to eq(group_2.id)
      end

      context "with set_primary_group" do
        let(:config) do
          {
            "operation" => "add",
            "username" => user.username,
            "group_id" => group.id.to_s,
            "set_primary_group" => true,
          }
        end

        it "sets the group as the user's primary group", :aggregate_failures do
          result = execute_node(configuration: config, item: item)

          expect(user.reload.primary_group_id).to eq(group.id)
          expect(GroupUser.exists?(user: user, group: group)).to be(true)
          expect(result["user"]["id"]).to eq(user.id)
          expect(result).to match_node_output_schema(described_class, configuration: config)
        end

        it "replaces an existing primary group and its title and flair", :aggregate_failures do
          group_2.update!(title: "Old title")
          group_2.add(user)
          user.update!(primary_group: group_2, flair_group: group_2, title: "Old title")
          group.update!(title: "New title")

          execute_node(configuration: config, item: item)

          user.reload
          expect(user.primary_group_id).to eq(group.id)
          expect(user.flair_group_id).to eq(group.id)
          expect(user.title).to eq("New title")
        end

        it "agrees with a group that automatically becomes the primary group",
           :aggregate_failures do
          group_2.update!(title: "Old title")
          group_2.add(user)
          user.update!(primary_group: group_2, flair_group: group_2, title: "Old title")
          group.update!(primary_group: true, title: "New title")

          execute_node(configuration: config, item: item)

          user.reload
          expect(user.primary_group_id).to eq(group.id)
          expect(user.flair_group_id).to eq(group.id)
          expect(user.title).to eq("New title")
        end

        it "sets the primary group when the user is already a member" do
          group.add(user)

          result = execute_node(configuration: config, item: item)

          expect(user.reload.primary_group_id).to eq(group.id)
          expect(result["changed"]).to be(true)
        end

        it "resolves the value from an expression" do
          config["set_primary_group"] = "={{ $json.make_primary }}"

          execute_node(configuration: config, item: { "json" => { "make_primary" => true } })

          expect(user.reload.primary_group_id).to eq(group.id)
        end
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
        expect(result["group"]["user_count"]).to eq(group.reload.user_count)
        expect(result["changed"]).to be(true)
        expect(GroupUser.exists?(user: user, group: group)).to be(false)
        expect(result).to match_node_output_schema(described_class, configuration: config)
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
        node_error_message(:not_found, scope: :actor, username: "nonexistent_user"),
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
        expect(result).to match_node_output_schema(described_class, configuration: config)
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
        configuration = {
          "operation" => "check_membership",
          "username" => "={{ $json.username }}",
          "group_id" => group.id,
          "actor_username" => "system",
        }

        output =
          execute_node_output(
            configuration: configuration,
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

        output.first.each do |output_item|
          expect(output_item["json"]).to match_node_output_schema(
            described_class,
            configuration: configuration,
          )
        end
      end

      it "replaces an existing membership object in both runtime data and its schema contract",
         :aggregate_failures do
        configuration = {
          "operation" => "check_membership",
          "username" => member.username,
          "group_id" => group.id,
          "actor_username" => "system",
        }
        input_schema = {
          "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
          "type" => "object",
          "properties" => {
            "group_membership" => {
              "type" => "object",
              "properties" => {
                "legacy" => {
                  "type" => "string",
                },
              },
            },
          },
        }

        output =
          execute_node_output(
            configuration: configuration,
            input_items: [{ "json" => { "group_membership" => { "legacy" => "old" } } }],
          )
        output_schema =
          described_class.output_schemas(configuration, input_schemas: [input_schema]).first

        expected_keys = %w[group_id group_name user_id username in_group]
        expect(output.first.first.dig("json", "group_membership").keys).to contain_exactly(
          *expected_keys,
        )
        expect(
          output_schema.dig("properties", "group_membership", "properties").keys,
        ).to contain_exactly(*expected_keys)
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
        end.to raise_error(
          DiscourseWorkflows::NodeError,
          node_error_message(:not_found, scope: :actor, username: "missing_user"),
        )
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

RSpec.describe DiscourseWorkflows::Nodes::Group::V2 do
  fab!(:user)
  fab!(:group)

  let(:item) { { "json" => { "source" => "post" } } }

  it "checks membership when no operation is set", :aggregate_failures do
    group.add(user)
    config = { "username" => user.username, "group_id" => group.id.to_s }

    result = execute_node(configuration: config, item:)

    expect(result).to include(
      "source" => "post",
      "group_membership" => include("group_id" => group.id, "in_group" => true),
    )
    expect(GroupUser.where(group:).count).to eq(1)
  end

  it "reads a group" do
    config = { "operation" => "get", "group_id" => group.id.to_s }

    result = execute_node(configuration: config, item:)

    expect(result).to match_node_output_schema(described_class, configuration: config)
  end

  it "refuses an operation that moved to its own node", :aggregate_failures do
    config = { "operation" => "add", "username" => user.username, "group_id" => group.id.to_s }

    expect { execute_node(configuration: config, item:) }.to raise_error(
      DiscourseWorkflows::NodeError,
      "#{I18n.t("discourse_workflows.errors.unknown_operation", operation: "add")} [item 0]",
    )
    expect(group.users).to be_empty
  end

  it "only offers reads, without the primary group setting", :aggregate_failures do
    expect(described_class.properties.dig(:operation, :options)).to eq(%w[get check_membership])
    expect(described_class.properties).not_to have_key(:set_primary_group)
    expect(described_class.output_schemas({ "operation" => "get" })).to eq(
      [DiscourseWorkflows::Schema::GROUP_SCHEMA],
    )
  end
end
