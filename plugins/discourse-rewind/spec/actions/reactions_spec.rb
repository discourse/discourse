# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::Reactions do
  fab!(:user)

  before { SiteSetting.discourse_reactions_enabled = true }

  describe ".call" do
    it "returns nothing when the user has no post reactions" do
      expect(call_report).to be_nil
    end

    it "counts the reactions used and received during the year" do
      own_post = Fabricate(:post, user:)
      received = Fabricate(:reaction, post: own_post, created_at: 2.years.ago)
      3.times do
        Fabricate(:reaction_user, reaction: received, post: own_post, created_at: random_datetime)
      end
      Fabricate(:reaction_user, reaction: received, post: own_post, created_at: 2.years.ago)
      used = Fabricate(:reaction, post: Fabricate(:post), reaction_value: "heart")
      Fabricate(:reaction_user, reaction: used, user:, post: used.post, created_at: random_datetime)

      other_received = Fabricate(:reaction, post: Fabricate(:post, user:), reaction_value: "heart")
      Fabricate(
        :reaction_user,
        reaction: other_received,
        post: other_received.post,
        created_at: random_datetime,
      )

      expect(call_report[:data]).to eq(
        post_used_reactions: [{ emoji: "heart", count: 1 }],
        post_used_reactions_total: 1,
        post_received_reactions: [{ emoji: "otter", count: 3 }, { emoji: "heart", count: 1 }],
      )
    end
  end
end
