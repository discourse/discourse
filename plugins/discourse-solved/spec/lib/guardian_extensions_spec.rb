# frozen_string_literal: true

require "rails_helper"

describe DiscourseSolved::GuardianExtensions do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic_with_op) }
  fab!(:post) { Fabricate(:post, topic: topic, user: other_user) }

  let(:guardian) { user.guardian }

  before { SiteSetting.allow_solved_on_all_topics = true }

  describe ".can_accept_answer?" do
    it "returns false for anon users" do
      expect(Guardian.new.can_accept_answer?(topic, post)).to eq(false)
    end

    it "returns false if the topic is nil, the post is nil, for the first post or for whispers" do
      expect(guardian.can_accept_answer?(nil, post)).to eq(false)
      expect(guardian.can_accept_answer?(topic, nil)).to eq(false)
      expect(guardian.can_accept_answer?(topic, topic.first_post)).to eq(false)

      post.update!(post_type: Post.types[:whisper])
      expect(guardian.can_accept_answer?(topic, post)).to eq(false)
    end

    it "returns false for private messages" do
      topic.update!(user:, category_id: nil, archetype: Archetype.private_message)
      expect(guardian.can_accept_answer?(topic, post)).to eq(false)
    end

    it "returns false if accepted answers are not allowed" do
      SiteSetting.allow_solved_on_all_topics = false
      expect(guardian.can_accept_answer?(topic, post)).to eq(false)
    end

    it "returns true for admins" do
      expect(
        Guardian.new(Fabricate(:admin, refresh_auto_groups: true)).can_accept_answer?(topic, post),
      ).to eq(true)
    end

    it "returns true if the user is in a group allowed to accept solutions" do
      SiteSetting.accept_all_solutions_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      expect(guardian.can_accept_answer?(topic, post)).to eq(true)
      SiteSetting.accept_all_solutions_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
      expect(guardian.can_accept_answer?(topic, post)).to eq(false)
    end

    it "returns true if the user is a category group moderator for the topic" do
      group = Fabricate(:group)
      group.add(user)
      category = Fabricate(:category)
      Fabricate(:category_moderation_group, category:, group:)
      topic.update!(category: category)
      SiteSetting.enable_category_group_moderation = true
      expect(guardian.can_accept_answer?(topic, post)).to eq(true)
    end

    it "returns true if the user is the topic author for an open topic" do
      SiteSetting.accept_solutions_topic_author = true
      topic.update!(user: user)
      expect(guardian.can_accept_answer?(topic, post)).to eq(true)
    end

    it "returns false if the user is trust level 4 but the trust level 4 group is not allowd to accept solutions" do
      SiteSetting.accept_all_solutions_allowed_groups = Fabricate(:group).id
      user.update!(trust_level: TrustLevel[4])
      expect(guardian.can_accept_answer?(topic, post)).to eq(false)
    end
  end
end
