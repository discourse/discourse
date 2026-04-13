# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::AssignTopic do
  fab!(:post)
  fab!(:topic) { post.topic }
  fab!(:user, :moderator)
  fab!(:group)

  let(:assign_allowed_group) { Group.find_by(name: "staff") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.assign_enabled = true
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

    context "with assign operation" do
      it "assigns the topic to a user" do
        config = {
          "operation" => "assign",
          "topic_id" => topic.id.to_s,
          "assignee" => user.username,
        }

        result = execute_node(configuration: config, item: item)

        expect(result["assigned_user"]["user_id"]).to eq(user.id)
        expect(result["assigned_user"]["username"]).to eq(user.username)
        expect(Assignment.exists?(target: topic, assigned_to: user)).to eq(true)
      end

      it "assigns the topic to a group" do
        SiteSetting.assign_allowed_on_groups = "#{assign_allowed_group.id}|#{group.id}"
        group.update!(assignable_level: Group::ALIAS_LEVELS[:everyone])

        config = { "operation" => "assign", "topic_id" => topic.id.to_s, "assignee" => group.name }

        result = execute_node(configuration: config, item: item)

        expect(result["assigned_user"]["user_id"]).to be_nil
        expect(Assignment.exists?(target: topic, assigned_to: group)).to eq(true)
      end

      it "raises when assignee does not exist" do
        config = {
          "operation" => "assign",
          "topic_id" => topic.id.to_s,
          "assignee" => "nonexistent",
        }

        expect { execute_node(configuration: config, item: item) }.to raise_error(RuntimeError)
      end

      context "when topic is already assigned" do
        fab!(:other_user, :moderator)

        before { ::Assigner.new(topic, Discourse.system_user).assign(other_user) }

        it "replaces the existing assignment by default" do
          config = {
            "operation" => "assign",
            "topic_id" => topic.id.to_s,
            "assignee" => user.username,
          }

          result = execute_node(configuration: config, item: item)

          expect(result["assigned_user"]["username"]).to eq(user.username)
          expect(result["unassigned_user"]["username"]).to eq(other_user.username)
          expect(Assignment.find_by(target: topic).assigned_to).to eq(user)
        end

        it "replaces the existing assignment when replace_existing is true" do
          config = {
            "operation" => "assign",
            "topic_id" => topic.id.to_s,
            "assignee" => user.username,
            "replace_existing" => true,
          }

          result = execute_node(configuration: config, item: item)

          expect(result["assigned_user"]["username"]).to eq(user.username)
          expect(Assignment.find_by(target: topic).assigned_to).to eq(user)
        end

        it "raises when replace_existing is false and same user is assigned" do
          config = {
            "operation" => "assign",
            "topic_id" => topic.id.to_s,
            "assignee" => other_user.username,
            "replace_existing" => false,
          }

          expect { execute_node(configuration: config, item: item) }.to raise_error(RuntimeError)
        end
      end

      it "uses run_as_user for the assigner" do
        run_as = Fabricate(:moderator)

        config = {
          "operation" => "assign",
          "topic_id" => topic.id.to_s,
          "assignee" => user.username,
        }

        execute_node(configuration: config, item: item, run_as_user: run_as)

        expect(topic.assignment.assigned_by_user_id).to eq(run_as.id)
      end
    end

    context "with unassign operation" do
      before { ::Assigner.new(topic, Discourse.system_user).assign(user) }

      it "unassigns the topic" do
        config = { "operation" => "unassign", "topic_id" => topic.id.to_s }

        result = execute_node(configuration: config, item: item)

        expect(result["unassigned_user"]["username"]).to eq(user.username)
        expect(Assignment.exists?(target: topic)).to eq(false)
      end

      it "is idempotent when topic is not assigned" do
        ::Assigner.new(topic, Discourse.system_user).unassign

        config = { "operation" => "unassign", "topic_id" => topic.id.to_s }

        expect { execute_node(configuration: config, item: item) }.not_to raise_error
      end
    end
  end
end
