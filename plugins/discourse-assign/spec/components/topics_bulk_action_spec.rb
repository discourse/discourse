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
    it "assigns multiple topics to user" do
      TopicsBulkAction.new(
        user,
        [post.topic.id, post1.topic.id],
        { type: "assign", username: user.username, note: "foobar" },
      ).perform!

      assigned_topics = TopicQuery.new(user, { page: 0 }).list_messages_assigned(user).topics

      expect(assigned_topics.length).to eq(2)

      expect(assigned_topics).to contain_exactly(post.topic, post1.topic)

      expect(post.topic.assignment.note).to eq "foobar"
      expect(post1.topic.assignment.note).to eq "foobar"
    end

    it "doesn't allows to assign to user not in assign_allowed_group" do
      TopicsBulkAction.new(
        user,
        [post.topic.id, post1.topic.id],
        { type: "assign", username: user2.username },
      ).perform!

      assigned_topics = TopicQuery.new(user, { page: 0 }).list_messages_assigned(user2).topics

      expect(assigned_topics.length).to eq(0)
    end

    it "user who is not in assign_allowed_group can't assign topics" do
      TopicsBulkAction.new(
        user2,
        [post.topic.id, post1.topic.id, post2.topic.id],
        { type: "assign", username: user.username },
      ).perform!

      assigned_topics = TopicQuery.new(user, { page: 0 }).list_messages_assigned(user).topics

      expect(assigned_topics.length).to eq(0)
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
