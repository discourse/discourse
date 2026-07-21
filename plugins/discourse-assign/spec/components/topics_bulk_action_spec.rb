# frozen_string_literal: true

require_relative "../support/assign_allowed_group"

describe TopicsBulkAction do
  fab!(:post)
  fab!(:post1, :post)
  fab!(:post2, :post)

  before { SiteSetting.assign_enabled = true }

  let(:user) { Fabricate(:user) }
  let(:user2) { Fabricate(:user) }

  include_context "with group that is allowed to assign"

  before { add_to_assign_allowed_group(user) }

  describe "assign_topics" do
    it "assigns multiple topics to a user" do
      changed_ids =
        TopicsBulkAction.new(
          user,
          [post.topic.id, post1.topic.id],
          { type: "assign", username: user.username, note: "foobar" },
        ).perform!

      expect(changed_ids).to contain_exactly(post.topic.id, post1.topic.id)
      expect(post.topic.reload.assignment).to have_attributes(
        assigned_to: user,
        assigned_to_type: "User",
        note: "foobar",
      )
      expect(post1.topic.reload.assignment.assigned_to).to eq(user)
    end

    it "reports a user who does not belong to an assign allowed group" do
      action =
        TopicsBulkAction.new(
          user,
          [post.topic.id, post1.topic.id],
          { type: "assign", username: user2.username },
        )

      expect(action.perform!).to be_empty
      expect(action.errors).to eq(
        I18n.t("discourse_assign.forbidden_assign_to", username: user2.username) => 2,
      )
    end

    it "refuses a user who is not allowed to assign" do
      expect {
        TopicsBulkAction.new(
          user2,
          [post.topic.id, post1.topic.id, post2.topic.id],
          { type: "assign", username: user.username },
        ).perform!
      }.to raise_error(Discourse::InvalidAccess)

      expect(Assignment.count).to eq(0)
    end

    it "reports a group that cannot be assigned" do
      unassignable_group = Fabricate(:group)

      action =
        TopicsBulkAction.new(
          user,
          [post.topic.id, post1.topic.id],
          { type: "assign", group_name: unassignable_group.name },
        )

      expect(action.perform!).to be_empty
      expect(action.errors).to eq(
        I18n.t("discourse_assign.forbidden_group_assign_to", group: unassignable_group.name) => 2,
      )
    end

    it "skips topics the acting user cannot see" do
      secret_topic =
        Fabricate(:topic, category: Fabricate(:private_category, group: Fabricate(:group)))

      action =
        TopicsBulkAction.new(
          user,
          [secret_topic.id, post.topic.id],
          { type: "assign", group_name: assign_allowed_group.name },
        )

      expect(action.perform!).to contain_exactly(post.topic.id)
      expect(action.errors).to be_empty
      expect(secret_topic.reload.assignment).to be_blank
    end
  end

  describe "unassign_topics" do
    it "unassigns multiple topics assigned to user" do
      TopicsBulkAction.new(
        user,
        [post.topic.id, post1.topic.id, post2.topic.id],
        { type: "assign", username: user.username },
      ).perform!

      TopicsBulkAction.new(user, [post.topic.id, post1.topic.id], type: "unassign").perform!

      assigned_topics = TopicQuery.new(user, { page: 0 }).list_messages_assigned(user).topics

      expect(assigned_topics.length).to eq(1)

      expect(assigned_topics).to contain_exactly(post2.topic)
    end

    it "user who is not in assign_allowed_group can't unassign topics" do
      TopicsBulkAction.new(
        user,
        [post.topic.id, post1.topic.id, post2.topic.id],
        { type: "assign", username: user.username },
      ).perform!

      TopicsBulkAction.new(user2, [post.topic.id, post1.topic.id], type: "unassign").perform!

      assigned_topics = TopicQuery.new(user, { page: 0 }).list_messages_assigned(user).topics

      expect(assigned_topics.length).to eq(3)

      expect(assigned_topics).to contain_exactly(post.topic, post1.topic, post2.topic)
    end

    it "category scoped users only unassign topics in allowed categories" do
      SiteSetting.assign_allowed_on_groups = ""
      allowed_category = Fabricate(:category)
      other_category = Fabricate(:category)
      post.topic.update!(category: allowed_category)
      post1.topic.update!(category: other_category)
      allow_group_to_assign_in_category(allowed_category, assign_allowed_group)
      Fabricate(
        :topic_assignment,
        target: post.topic,
        assigned_to: user,
        assigned_by_user: Discourse.system_user,
      )
      Fabricate(
        :topic_assignment,
        target: post1.topic,
        assigned_to: user,
        assigned_by_user: Discourse.system_user,
      )

      TopicsBulkAction.new(user, [post.topic.id, post1.topic.id], type: "unassign").perform!

      expect(post.topic.reload.assignment).to be_blank
      expect(post1.topic.reload.assignment).to be_present
    end
  end
end
