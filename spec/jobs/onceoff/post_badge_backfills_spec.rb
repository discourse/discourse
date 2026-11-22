# frozen_string_literal: true

RSpec.describe Jobs::Onceoff do
  fab!(:user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:category) { Fabricate(:private_category, group: Fabricate(:group)) }
  fab!(:topic) { Fabricate(:topic, category: category) }

  before { SiteSetting.enable_badges = true }

  describe Jobs::GrantEmoji do
    it "awards emoji posts in restricted categories without anonymous topic access" do
      post =
        Fabricate(
          :post,
          user: user,
          topic: topic,
          cooked: '<p><img class="emoji" src="/emoji.png"></p>',
        )

      described_class.new.execute_onceoff({})

      expect(
        UserBadge.where(user: user, badge_id: Badge::FirstEmoji).pluck(:post_id),
      ).to contain_exactly(post.id)
    end
  end

  describe Jobs::GrantOnebox do
    it "awards oneboxes in restricted categories without anonymous topic access" do
      post = Fabricate(:post, user: user, topic: topic, raw: "https://example.com")

      described_class.new.execute_onceoff({})

      expect(
        UserBadge.where(user: user, badge_id: Badge::FirstOnebox).pluck(:post_id),
      ).to contain_exactly(post.id)
    end
  end

  describe Jobs::GrantFirstReplyByEmail do
    it "awards email replies in restricted categories without anonymous topic access" do
      Fabricate(:post, topic: topic)
      post = Fabricate(:post, user: user, topic: topic, via_email: true)

      described_class.new.execute_onceoff({})

      expect(
        UserBadge.where(user: user, badge_id: Badge::FirstReplyByEmail).pluck(:post_id),
      ).to contain_exactly(post.id)
    end
  end
end
