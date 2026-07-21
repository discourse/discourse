# frozen_string_literal: true

require_relative "../support/assign_allowed_group"

RSpec.describe TopicsController do
  include_context "with group that is allowed to assign"

  fab!(:actor, :user)
  fab!(:allowed_user, :user)
  fab!(:topic1) { Fabricate(:post).topic }
  fab!(:topic2) { Fabricate(:post).topic }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.enable_assign_status = true
    add_to_assign_allowed_group(actor)
    sign_in(actor)
  end

  def bulk_assign(operation, ids: [topic1.id, topic2.id])
    put "/topics/bulk.json", params: { topic_ids: ids, operation: operation }
  end

  describe "#bulk with the assign operation" do
    it "assigns the selected topics to a group, carrying the note and the status" do
      bulk_assign(
        {
          type: "assign",
          group_name: assign_allowed_group.name,
          note: "handle this",
          status: "In Progress",
        },
      )

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(topic1.id, topic2.id)
      expect(topic1.reload.assignment).to have_attributes(
        assigned_to: assign_allowed_group,
        assigned_to_type: "Group",
        note: "handle this",
        status: "In Progress",
      )
      expect(topic2.reload.assignment.assigned_to).to eq(assign_allowed_group)
    end

    it "returns a 400 when the operation names no assignee" do
      bulk_assign({ type: "assign" })

      expect(response.status).to eq(400)
      expect(Assignment.count).to eq(0)
    end

    it "returns a 404 when the group name matches no group" do
      bulk_assign({ type: "assign", group_name: "no-such-group" })

      expect(response.status).to eq(404)
    end

    it "returns a 422 when the status is not one of the configured statuses" do
      bulk_assign({ type: "assign", group_name: assign_allowed_group.name, status: "Bogus" })

      expect(response.status).to eq(422)
      expect(Assignment.count).to eq(0)
    end

    it "returns a 403 without disclosing a group the acting user cannot see" do
      hidden_group =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:staff],
          assignable_level: Group::ALIAS_LEVELS[:everyone],
        )

      bulk_assign({ type: "assign", group_name: hidden_group.name })

      expect(response.status).to eq(403)
      expect(response.body).not_to include(hidden_group.name)
      expect(Assignment.count).to eq(0)
    end

    it "returns a 403 when the acting user is not allowed to assign" do
      sign_in(Fabricate(:user))

      bulk_assign({ type: "assign", group_name: assign_allowed_group.name })

      expect(response.status).to eq(403)
      expect(Assignment.count).to eq(0)
    end

    it "returns the per-topic failures alongside the topics that succeeded" do
      add_to_assign_allowed_group(allowed_user)
      private_group = Fabricate(:group, users: [actor])
      hidden_topic = Fabricate(:topic, category: Fabricate(:private_category, group: private_group))

      bulk_assign(
        { type: "assign", username: allowed_user.username },
        ids: [hidden_topic.id, topic2.id],
      )

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(topic2.id)
      expect(response.parsed_body["errors"]).to eq(
        I18n.t(
          "discourse_assign.forbidden_assignee_cant_see_topic",
          username: allowed_user.username,
        ) =>
          1,
      )
    end

    it "reports the topics already assigned to the same assignee as succeeded" do
      Assigner.new(topic1, actor).assign(assign_allowed_group)

      bulk_assign({ type: "assign", group_name: assign_allowed_group.name })

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(topic1.id, topic2.id)
      expect(response.parsed_body["errors"]).to be_blank
    end

    it "keeps assigning the rest of the selection when a PM invite is refused" do
      SiteSetting.invite_on_assign = true
      pm = Fabricate(:private_message_topic, user: actor, recipient: allowed_user)
      Fabricate(:post, topic: pm)
      assign_allowed_group.add(Fabricate(:user))

      bulk_assign(
        { type: "assign", group_name: assign_allowed_group.name },
        ids: [topic1.id, pm.id],
      )

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(topic1.id)
      expect(response.parsed_body["errors"]).to eq(
        I18n.t(
          "discourse_assign.forbidden_group_assignee_not_pm_participant",
          group: assign_allowed_group.name,
        ) =>
          1,
      )
    end
  end
end
