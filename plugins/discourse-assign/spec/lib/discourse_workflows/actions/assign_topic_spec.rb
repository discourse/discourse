# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Actions::AssignTopic do
  fab!(:post)
  fab!(:topic) { post.topic }
  fab!(:user, :moderator)
  fab!(:group)

  let(:assign_allowed_group) { Group.find_by(name: "staff") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.assign_enabled = true
  end

  describe "#execute_single" do
    let(:action) { described_class.new(configuration: {}) }
    let(:item) { { "json" => {} } }

    context "with assign operation" do
      it "assigns the topic to a user" do
        config = {
          "operation" => "assign",
          "topic_id" => topic.id.to_s,
          "assignee" => user.username,
        }

        result = action.execute_single({}, item: item, config: config)

        expect(result[:topic_id]).to eq(topic.id)
        expect(result[:topic_title]).to eq(topic.title)
        expect(result[:assigned_to]).to eq(user.username)
        expect(result[:assigned_to_type]).to eq("User")
        expect(Assignment.exists?(target: topic, assigned_to: user)).to eq(true)
      end

      it "assigns the topic to a group" do
        SiteSetting.assign_allowed_on_groups = "#{assign_allowed_group.id}|#{group.id}"
        group.update!(assignable_level: Group::ALIAS_LEVELS[:everyone])

        config = { "operation" => "assign", "topic_id" => topic.id.to_s, "assignee" => group.name }

        result = action.execute_single({}, item: item, config: config)

        expect(result[:assigned_to]).to eq(group.name)
        expect(result[:assigned_to_type]).to eq("Group")
        expect(Assignment.exists?(target: topic, assigned_to: group)).to eq(true)
      end

      it "raises when assignee does not exist" do
        config = {
          "operation" => "assign",
          "topic_id" => topic.id.to_s,
          "assignee" => "nonexistent",
        }

        expect { action.execute_single({}, item: item, config: config) }.to raise_error(
          RuntimeError,
        )
      end
    end

    context "with unassign operation" do
      before { ::Assigner.new(topic, Discourse.system_user).assign(user) }

      it "unassigns the topic" do
        config = { "operation" => "unassign", "topic_id" => topic.id.to_s }

        result = action.execute_single({}, item: item, config: config)

        expect(result[:topic_id]).to eq(topic.id)
        expect(result[:assigned_to]).to be_nil
        expect(Assignment.exists?(target: topic)).to eq(false)
      end

      it "is idempotent when topic is not assigned" do
        ::Assigner.new(topic, Discourse.system_user).unassign

        config = { "operation" => "unassign", "topic_id" => topic.id.to_s }

        expect { action.execute_single({}, item: item, config: config) }.not_to raise_error
      end
    end
  end
end
