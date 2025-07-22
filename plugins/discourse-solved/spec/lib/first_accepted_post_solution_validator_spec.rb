# frozen_string_literal: true

describe DiscourseSolved::FirstAcceptedPostSolutionValidator do
  fab!(:user_tl1) { Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true) }

  context "when trust level is 'any'" do
    it "validates the post" do
      post = Fabricate(:post, user: user_tl1)
      DiscourseSolved.accept_answer!(post, Discourse.system_user)

      expect(described_class.check(post, trust_level: "any")).to eq(true)
    end

    it "invalidates if post user already has an accepted post" do
      previously_accepted_post = Fabricate(:post, user: user_tl1)
      DiscourseSolved.accept_answer!(previously_accepted_post, Discourse.system_user)

      newly_accepted_post = Fabricate(:post, user: user_tl1)
      DiscourseSolved.accept_answer!(newly_accepted_post, Discourse.system_user)

      expect(described_class.check(newly_accepted_post, trust_level: "any")).to eq(false)
    end
  end

  context "with specified trust level that is not 'any'" do
    # the automation indicates "users under this Trust Level will trigger this automation"

    it "invalidates if the user is higher than or equal to the specified trust level" do
      post = Fabricate(:post, user: user_tl1)
      DiscourseSolved.accept_answer!(post, Discourse.system_user)

      expect(described_class.check(post, trust_level: TrustLevel[0])).to eq(false)
      expect(described_class.check(post, trust_level: TrustLevel[1])).to eq(false)
    end

    it "validates the post when user is under specified trust level" do
      post = Fabricate(:post, user: user_tl1)
      DiscourseSolved.accept_answer!(post, Discourse.system_user)

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
