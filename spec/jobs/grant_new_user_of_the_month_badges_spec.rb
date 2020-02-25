# frozen_string_literal: true

require 'rails_helper'

describe Jobs::GrantNewUserOfTheMonthBadges do

  let(:granter) { described_class.new }

  it "runs correctly" do
    freeze_time(DateTime.parse('2019-11-30 23:59 UTC'))

    u0 = Fabricate(:user, created_at: 2.weeks.ago)
    BadgeGranter.grant(Badge.find(Badge::NewUserOfTheMonth), u0, created_at: Time.now)

    freeze_time(DateTime.parse('2020-01-01 00:00 UTC'))

    user = Fabricate(:user, created_at: 1.week.ago)
    p = Fabricate(:post, user: user)
    Fabricate(:post, user: user)

    old_user = Fabricate(:user, created_at: 6.months.ago)
    PostActionCreator.like(old_user, p)
    old_user = Fabricate(:user, created_at: 6.months.ago)
    PostActionCreator.like(old_user, p)

    granter.execute({})

    badges = user.user_badges.where(badge_id: Badge::NewUserOfTheMonth)
    expect(badges).to be_present
    expect(badges.first.granted_at.to_s).to eq('2019-12-31 23:59:59 UTC')
  end

  it "does nothing if badges are disabled" do
    SiteSetting.enable_badges = false

    user = Fabricate(:user, created_at: 1.week.ago)
    p = Fabricate(:post, user: user)
    Fabricate(:post, user: user)

    old_user = Fabricate(:user, created_at: 6.months.ago)
    PostActionCreator.like(old_user, p)
    old_user = Fabricate(:user, created_at: 6.months.ago)
    PostActionCreator.like(old_user, p)

    SystemMessage.any_instance.expects(:create).never
    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::NewUserOfTheMonth)
    expect(badge).to be_blank
  end

  it "does nothing if the badge is disabled" do
    Badge.find(Badge::NewUserOfTheMonth).update_column(:enabled, false)

    user = Fabricate(:user, created_at: 1.week.ago)
    p = Fabricate(:post, user: user)
    Fabricate(:post, user: user)

    old_user = Fabricate(:user, created_at: 6.months.ago)
    PostActionCreator.like(old_user, p)
    old_user = Fabricate(:user, created_at: 6.months.ago)
    PostActionCreator.like(old_user, p)

    SystemMessage.any_instance.expects(:create).never
    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::NewUserOfTheMonth)
    expect(badge).to be_blank
  end

  it "does nothing if it's already been awarded in previous month" do
    freeze_time(DateTime.parse('2019-11-30 23:59 UTC'))

    u0 = Fabricate(:user, created_at: 2.weeks.ago)
    BadgeGranter.grant(Badge.find(Badge::NewUserOfTheMonth), u0, created_at: Time.now)

    freeze_time(DateTime.parse('2019-12-01 00:00 UTC'))

    user = Fabricate(:user, created_at: 1.week.ago)
    p = Fabricate(:post, user: user)
    Fabricate(:post, user: user)

    old_user = Fabricate(:user, created_at: 6.months.ago)
    PostActionCreator.like(old_user, p)
    old_user = Fabricate(:user, created_at: 6.months.ago)
    PostActionCreator.like(old_user, p)

    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::NewUserOfTheMonth)
    expect(badge).to be_blank
  end

  describe '.scores' do
    def scores
      granter.scores(1.month.ago)
    end

    it "doesn't award it to accounts over a month old" do
      user = Fabricate(:user, created_at: 2.months.ago)
      Fabricate(:post, user: user)
      p = Fabricate(:post, user: user)
      old_user = Fabricate(:user, created_at: 6.months.ago)
      PostActionCreator.like(old_user, p)
      old_user = Fabricate(:user, created_at: 6.months.ago)
      PostActionCreator.like(old_user, p)

      expect(scores.keys).not_to include(user.id)
    end

    it "doesn't score users who haven't posted in two topics" do
      user = Fabricate(:user, created_at: 1.week.ago)
      p = Fabricate(:post, user: user)
      old_user = Fabricate(:user, created_at: 6.months.ago)
      PostActionCreator.like(old_user, p)
      old_user = Fabricate(:user, created_at: 6.months.ago)
      PostActionCreator.like(old_user, p)

      expect(scores.keys).not_to include(user.id)
    end

    it "doesn't count private topics" do
      user = Fabricate(:user, created_at: 1.week.ago)
      topic = Fabricate(:private_message_topic)
      Fabricate(:post, topic: topic, user: user)
      p = Fabricate(:post, user: user)
      old_user = Fabricate(:user, created_at: 6.months.ago)
      PostActionCreator.like(old_user, p)
      old_user = Fabricate(:user, created_at: 6.months.ago)
      PostActionCreator.like(old_user, p)

      expect(scores.keys).not_to include(user.id)
    end

    it "requires at least two likes to be considered" do
      user = Fabricate(:user, created_at: 1.week.ago)
      Fabricate(:post, user: user)
      p = Fabricate(:post, user: user)
      old_user = Fabricate(:user, created_at: 6.months.ago)
      PostActionCreator.like(old_user, p)

      expect(scores.keys).not_to include(user.id)
    end

    it "returns scores for accounts created within the last month" do
      user = Fabricate(:user, created_at: 1.week.ago)
      Fabricate(:post, user: user)
      p = Fabricate(:post, user: user)
      old_user = Fabricate(:user, created_at: 6.months.ago)
      PostActionCreator.like(old_user, p)
      old_user = Fabricate(:user, created_at: 6.months.ago)
      PostActionCreator.like(old_user, p)

      expect(scores.keys).to include(user.id)
    end

    it "likes from older accounts are scored higher" do
      user = Fabricate(:user, created_at: 1.week.ago)
      p = Fabricate(:post, user: user)
      Fabricate(:post, user: user)

      u0 = Fabricate(:user, trust_level: 0)
      u1 = Fabricate(:user, trust_level: 1)
      u2 = Fabricate(:user, trust_level: 2)
      u3 = Fabricate(:user, trust_level: 3)
      u4 = Fabricate(:user, trust_level: 4)
      um = Fabricate(:user, trust_level: 3, moderator: true)
      ua = Fabricate(:user, trust_level: 0, admin: true)

      PostActionCreator.like(u0, p)
      PostActionCreator.like(u1, p)
      PostActionCreator.like(u2, p)
      PostActionCreator.like(u3, p)
      PostActionCreator.like(u4, p)
      PostActionCreator.like(um, p)
      PostActionCreator.like(ua, p)
      PostActionCreator.like(Discourse.system_user, p)
      expect(scores[user.id]).to eq(1.55)

      # It goes down the more they post
      Fabricate(:post, user: user)
      expect(scores[user.id]).to eq(1.35625)
    end

    it "is limited to two accounts" do
      u1 = Fabricate(:user, created_at: 1.week.ago)
      u2 = Fabricate(:user, created_at: 2.weeks.ago)
      u3 = Fabricate(:user, created_at: 3.weeks.ago)

      ou1 = Fabricate(:user, created_at: 6.months.ago)
      ou2 = Fabricate(:user, created_at: 6.months.ago)

      p = Fabricate(:post, user: u1)
      Fabricate(:post, user: u1)
      PostActionCreator.like(ou1, p)
      PostActionCreator.like(ou2, p)

      p = Fabricate(:post, user: u2)
      Fabricate(:post, user: u2)
      PostActionCreator.like(ou1, p)
      PostActionCreator.like(ou2, p)

      p = Fabricate(:post, user: u3)
      Fabricate(:post, user: u3)
      PostActionCreator.like(ou1, p)
      PostActionCreator.like(ou2, p)

      expect(scores.keys.size).to eq(2)
    end

  end

end
