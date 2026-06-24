# frozen_string_literal: true

require_relative "../support/assign_allowed_group"

describe Search do
  fab!(:user, :active_user)
  fab!(:user2, :user)

  before do
    SearchIndexer.enable
    SiteSetting.assign_enabled = true
  end

  describe "Advanced search" do
    include_context "with group that is allowed to assign"

    let(:post1) { Fabricate(:post) }
    let(:post2) { Fabricate(:post) }
    let(:post3) { Fabricate(:post) }
    let(:post4) { Fabricate(:post) }
    let(:post5) { Fabricate(:post, topic: post4.topic) }
    let(:post6) { Fabricate(:post) }

    before do
      add_to_assign_allowed_group(user)
      add_to_assign_allowed_group(user2)

      Assigner.new(post1.topic, user).assign(user)
      Assigner.new(post2.topic, user).assign(user2)
      Assigner.new(post3.topic, user).assign(user)
      Assigner.new(post5, user).assign(user)
      Assignment.create!(
        assigned_to: user,
        assigned_by_user: user,
        target: post6,
        topic_id: post6.topic.id,
        active: false,
      )
    end

    it "can find by status" do
      expect(Search.execute("in:assigned", guardian: Guardian.new(user)).posts.length).to eq(4)

      Assigner.new(post3.topic, user).unassign

      expect(Search.execute("in:unassigned", guardian: Guardian.new(user)).posts.length).to eq(2)
      expect(
        Search.execute("assigned:#{user.username}", guardian: Guardian.new(user)).posts.length,
      ).to eq(2)
    end

    it "does not let assigned:<group> resolve a group the user cannot see" do
      hidden_group =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:staff],
          assignable_level: Group::ALIAS_LEVELS[:everyone],
        )
      hidden_post = Fabricate(:post)
      Assigner.new(hidden_post.topic, user).assign(hidden_group)

      # An admin can see the group, so the filter resolves and narrows to its topic.
      expect(
        Search
          .execute("assigned:#{hidden_group.name}", guardian: Guardian.new(Fabricate(:admin)))
          .posts
          .map(&:topic_id),
      ).to include(hidden_post.topic_id)

      # A non-staff assigner cannot see the group, so the name must not resolve: the
      # filter becomes a no-op (identical to an unknown name) and never narrows the
      # results to the hidden group's topics.
      cannot_see = Guardian.new(user)
      hidden_result = Search.execute("assigned:#{hidden_group.name}", guardian: cannot_see)
      unknown_result = Search.execute("assigned:#{hidden_group.name}-unknown", guardian: cannot_see)

      expect(hidden_result.posts.map(&:id).sort).to eq(unknown_result.posts.map(&:id).sort)
      expect(hidden_result.posts.map(&:topic_id)).to include(post1.topic_id)
    end

    it "serializes results" do
      guardian = Guardian.new(user)
      result = Search.execute("in:assigned", guardian: guardian)
      serializer = GroupedSearchResultSerializer.new(result, scope: guardian)
      indirectly_assigned_to =
        serializer.as_json[:topics].find { |topic| topic[:id] == post5.topic.id }[
          :indirectly_assigned_to
        ]
      expect(indirectly_assigned_to).to eq(
        post5.id => {
          assigned_to: {
            avatar_template: user.avatar_template,
            name: user.name,
            username: user.username,
          },
          post_number: post5.post_number,
          assignment_note: nil,
          assignment_status: nil,
        },
      )
    end
  end
end
