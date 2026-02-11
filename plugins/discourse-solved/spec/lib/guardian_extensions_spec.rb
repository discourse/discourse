# frozen_string_literal: true

describe DiscourseSolved::GuardianExtensions do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic, :topic_with_op)
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

    it "returns false for regular private messages" do
      pm = Fabricate(:private_message_topic, user: user)
      pm_post = Fabricate(:post, topic: pm, user: other_user)
      expect(guardian.can_accept_answer?(pm, pm_post)).to eq(false)
    end

    context "with group messages" do
      fab!(:group)
      fab!(:pm_topic) do
        Fabricate(:group_private_message_topic, user: user, recipient_group: group)
      end
      fab!(:pm_op) { Fabricate(:post, topic: pm_topic, user: user) }
      fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: other_user) }

      before { SiteSetting.allow_solved_on_all_topics = false }

      it "returns false when allow_solved_in_groups is empty" do
        SiteSetting.allow_solved_in_groups = ""
        expect(guardian.can_accept_answer?(pm_topic, pm_post)).to eq(false)
      end

      it "returns false when the group is not in allow_solved_in_groups" do
        other_group = Fabricate(:group)
        SiteSetting.allow_solved_in_groups = other_group.id.to_s
        expect(guardian.can_accept_answer?(pm_topic, pm_post)).to eq(false)
      end

      it "returns true for topic author when the group is in allow_solved_in_groups" do
        SiteSetting.allow_solved_in_groups = group.id.to_s
        SiteSetting.accept_solutions_topic_author = true
        expect(guardian.can_accept_answer?(pm_topic, pm_post)).to eq(true)
      end

      it "returns true for staff when the group is in allow_solved_in_groups" do
        SiteSetting.allow_solved_in_groups = group.id.to_s
        admin = Fabricate(:admin, refresh_auto_groups: true)
        expect(Guardian.new(admin).can_accept_answer?(pm_topic, pm_post)).to eq(true)
      end

      it "returns false for non-author non-staff users" do
        SiteSetting.allow_solved_in_groups = group.id.to_s
        non_author = Fabricate(:user, refresh_auto_groups: true)
        SiteSetting.accept_all_solutions_allowed_groups = Fabricate(:group).id
        expect(Guardian.new(non_author).can_accept_answer?(pm_topic, pm_post)).to eq(false)
      end
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

    it "returns false if the user is trust level 4 but the trust level 4 group is not allowed to accept solutions" do
      SiteSetting.accept_all_solutions_allowed_groups = Fabricate(:group).id
      user.update!(trust_level: TrustLevel[4])
      expect(guardian.can_accept_answer?(topic, post)).to eq(false)
    end
  end
end
