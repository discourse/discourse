# frozen_string_literal: true

describe DiscourseSolved::FirstAcceptedPostSolutionValidator do
  fab!(:user_tl1) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }

  before { SiteSetting.allow_solved_on_all_topics = true }

  context "when trust level is 'any'" do
    it "validates the post" do
      topic = Fabricate(:topic_with_op)
      post = Fabricate(:post, topic:, user: user_tl1)
      DiscourseSolved::AcceptAnswer.call!(
        params: {
          post_id: post.id,
        },
        guardian: Discourse.system_user.guardian,
      )

      expect(described_class.check(post, trust_level: "any")).to eq(true)
    end

    it "invalidates if post user already has an accepted post" do
      topic1 = Fabricate(:topic_with_op)
      previously_accepted_post = Fabricate(:post, topic: topic1, user: user_tl1)
      DiscourseSolved::AcceptAnswer.call!(
        params: {
          post_id: previously_accepted_post.id,
        },
        guardian: Discourse.system_user.guardian,
      )

      topic2 = Fabricate(:topic_with_op)
      newly_accepted_post = Fabricate(:post, topic: topic2, user: user_tl1)
      DiscourseSolved::AcceptAnswer.call!(
        params: {
          post_id: newly_accepted_post.id,
        },
        guardian: Discourse.system_user.guardian,
      )

      expect(described_class.check(newly_accepted_post, trust_level: "any")).to eq(false)
    end
  end

  context "with specified trust level that is not 'any'" do
    # the automation indicates "users under this Trust Level will trigger this automation"

    it "invalidates if the user is higher than or equal to the specified trust level" do
      topic = Fabricate(:topic_with_op)
      post = Fabricate(:post, topic:, user: user_tl1)
      DiscourseSolved::AcceptAnswer.call!(
        params: {
          post_id: post.id,
        },
        guardian: Discourse.system_user.guardian,
      )

      expect(described_class.check(post, trust_level: TrustLevel[0])).to eq(false)
      expect(described_class.check(post, trust_level: TrustLevel[1])).to eq(false)
    end

    it "validates the post when user is under specified trust level" do
      topic = Fabricate(:topic_with_op)
      post = Fabricate(:post, topic:, user: user_tl1)
      DiscourseSolved::AcceptAnswer.call!(
        params: {
          post_id: post.id,
        },
        guardian: Discourse.system_user.guardian,
      )

      expect(described_class.check(post, trust_level: TrustLevel[2])).to eq(true)
    end
  end

  context "when user is system" do
    it "doesn’t validate the post" do
      post_1 = create_post(user: Discourse.system_user)
      expect(described_class.check(post_1, trust_level: "any")).to eq(false)
    end
  end

  context "when post is a PM" do
    it "doesn’t validate the post" do
      Group.refresh_automatic_groups!
      post_1 =
        create_post(
          user: user_tl1,
          target_usernames: [user_tl1.username],
          archetype: Archetype.private_message,
        )
      expect(described_class.check(post_1, trust_level: "any")).to eq(false)
    end
  end
end
