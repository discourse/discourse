require 'rails_helper'
require_dependency 'jobs/scheduled/grant_rookie_badges'

describe Jobs::GrantRookieBadges do

  let(:granter) { described_class.new }

  it "runs correctly" do
    user = Fabricate(:user, created_at: 1.week.ago)
    p = Fabricate(:post, user: user)

    old_user = Fabricate(:user, created_at: 6.months.ago)
    PostAction.act(old_user, p, PostActionType.types[:like])

    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::RookieOfTheMonth)
    expect(badge).to be_present

  end

  describe '.scores' do

    it "doesn't award it to accounts over a month old" do
      user = Fabricate(:user, created_at: 2.months.ago)
      Fabricate(:post, user: user)
      expect(granter.scores.keys).not_to include(user.id)
    end

    it "returns active accounts created in the last month" do
      user = Fabricate(:user, created_at: 1.week.ago)
      Fabricate(:post, user: user)
      expect(granter.scores.keys).to include(user.id)
    end

    it "likes from older accounts are scored higher" do
      user = Fabricate(:user, created_at: 1.week.ago)
      p = Fabricate(:post, user: user)

      new_user = Fabricate(:user, created_at: 2.days.ago)
      med_user = Fabricate(:user, created_at: 3.weeks.ago)
      old_user = Fabricate(:user, created_at: 6.months.ago)

      PostAction.act(new_user, p, PostActionType.types[:like])
      PostAction.act(med_user, p, PostActionType.types[:like])
      PostAction.act(old_user, p, PostActionType.types[:like])
      expect(granter.scores[user.id]).to eq(1.6)

      # It goes down the more they post
      Fabricate(:post, user: user)
      expect(granter.scores[user.id]).to eq(0.8)
    end

    it "is limited to two accounts" do
      u1 = Fabricate(:user, created_at: 1.week.ago)
      u2 = Fabricate(:user, created_at: 2.weeks.ago)
      u3 = Fabricate(:user, created_at: 3.weeks.ago)

      Fabricate(:post, user: u1)
      Fabricate(:post, user: u2)
      Fabricate(:post, user: u3)

      expect(granter.scores.keys.size).to eq(2)
    end

  end

end
