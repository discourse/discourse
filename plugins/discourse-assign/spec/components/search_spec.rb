# frozen_string_literal: true

require "rails_helper"
require_relative "../support/assign_allowed_group"

describe Search do
  fab!(:user) { Fabricate(:active_user) }
  fab!(:user2) { Fabricate(:user) }

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
