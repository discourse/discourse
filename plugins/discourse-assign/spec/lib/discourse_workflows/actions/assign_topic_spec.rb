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

        expect(result[:assigned_user][:user_id]).to eq(user.id)
        expect(result[:assigned_user][:username]).to eq(user.username)
        expect(Assignment.exists?(target: topic, assigned_to: user)).to eq(true)
      end

      it "assigns the topic to a group" do
        SiteSetting.assign_allowed_on_groups = "#{assign_allowed_group.id}|#{group.id}"
        group.update!(assignable_level: Group::ALIAS_LEVELS[:everyone])

        config = { "operation" => "assign", "topic_id" => topic.id.to_s, "assignee" => group.name }

        result = action.execute_single({}, item: item, config: config)

        expect(result[:assigned_user][:user_id]).to be_nil
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

      context "when topic is already assigned" do
        fab!(:other_user, :moderator)

        before { ::Assigner.new(topic, Discourse.system_user).assign(other_user) }

        it "replaces the existing assignment by default" do
          config = {
            "operation" => "assign",
            "topic_id" => topic.id.to_s,
            "assignee" => user.username,
          }

          result = action.execute_single({}, item: item, config: config)

          expect(result[:assigned_user][:username]).to eq(user.username)
          expect(result[:unassigned_user][:username]).to eq(other_user.username)
          expect(Assignment.find_by(target: topic).assigned_to).to eq(user)
        end

        it "replaces the existing assignment when replace_existing is true" do
          config = {
            "operation" => "assign",
            "topic_id" => topic.id.to_s,
            "assignee" => user.username,
            "replace_existing" => true,
          }

          result = action.execute_single({}, item: item, config: config)

          expect(result[:assigned_user][:username]).to eq(user.username)
          expect(Assignment.find_by(target: topic).assigned_to).to eq(user)
        end

        it "raises when replace_existing is false and same user is assigned" do
          config = {
            "operation" => "assign",
            "topic_id" => topic.id.to_s,
            "assignee" => other_user.username,
            "replace_existing" => false,
          }

          expect { action.execute_single({}, item: item, config: config) }.to raise_error(
            RuntimeError,
          )
        end
      end

      it "uses run_as_user for the assigner" do
        run_as = Fabricate(:moderator)
        action.instance_variable_set(:@run_as_user, run_as)

        config = {
          "operation" => "assign",
          "topic_id" => topic.id.to_s,
          "assignee" => user.username,
        }

        action.execute_single({}, item: item, config: config)

        expect(topic.assignment.assigned_by_user_id).to eq(run_as.id)
      end
    end

    context "with unassign operation" do
      before { ::Assigner.new(topic, Discourse.system_user).assign(user) }

      it "unassigns the topic" do
        config = { "operation" => "unassign", "topic_id" => topic.id.to_s }

        result = action.execute_single({}, item: item, config: config)

        expect(result[:unassigned_user][:username]).to eq(user.username)
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
