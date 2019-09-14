# frozen_string_literal: true

require 'rails_helper'

describe Jobs::GrantAnniversaryBadges do

  let(:granter) { described_class.new }

  it "doesn't award to a user who is less than a year old" do
    user = Fabricate(:user, created_at: 1.month.ago)
    Fabricate(:post, user: user, created_at: 1.week.ago)
    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::Anniversary)
    expect(badge).to be_blank
  end

  it "doesn't award to an inactive user" do
    user = Fabricate(:user, created_at: 400.days.ago, active: false)
    Fabricate(:post, user: user, created_at: 1.week.ago)
    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::Anniversary)
    expect(badge).to be_blank
  end

  it "doesn't award to a silenced user" do
    user = Fabricate(:user, created_at: 400.days.ago, silenced_till: 1.year.from_now)
    Fabricate(:post, user: user, created_at: 1.week.ago)
    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::Anniversary)
    expect(badge).to be_blank
  end

  it "doesn't award when a post is deleted" do
    user = Fabricate(:user, created_at: 400.days.ago)
    Fabricate(:post, user: user, created_at: 1.week.ago, deleted_at: 1.day.ago)
    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::Anniversary)
    expect(badge).to be_blank
  end

  it "doesn't award when a post is hidden" do
    user = Fabricate(:user, created_at: 400.days.ago)
    Fabricate(:post, user: user, created_at: 1.week.ago, hidden: true)
    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::Anniversary)
    expect(badge).to be_blank
  end

  it "doesn't award to PMs" do
    user = Fabricate(:user, created_at: 400.days.ago)
    Fabricate(:private_message_post, user: user, created_at: 1.week.ago)
    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::Anniversary)
    expect(badge).to be_blank
  end

  it "doesn't award to a user without a post" do
    user = Fabricate(:user, created_at: 1.month.ago)
    granter.execute({})

    badge = user.user_badges.where(badge_id: Badge::Anniversary)
    expect(badge).to be_blank
  end

  it "doesn't award when badges are disabled" do
    SiteSetting.enable_badges = false

    user = Fabricate(:user, created_at: 400.days.ago)
    Fabricate(:post, user: user, created_at: 1.week.ago)

    granter.execute({})
    badge = user.user_badges.where(badge_id: Badge::Anniversary)
    expect(badge.count).to eq(0)
  end

  it "awards the badge to a user with a post active for a year" do
    user = Fabricate(:user, created_at: 400.days.ago)
    Fabricate(:post, user: user, created_at: 1.week.ago)

    granter.execute({})
    badge = user.user_badges.where(badge_id: Badge::Anniversary)
    expect(badge.count).to eq(1)
  end

  context "repeated grants" do
    it "won't award twice in the same year" do
      user = Fabricate(:user, created_at: 400.days.ago)
      Fabricate(:post, user: user, created_at: 1.week.ago)

      granter.execute({})
      granter.execute({})
      badge = user.user_badges.where(badge_id: Badge::Anniversary)
      expect(badge.count).to eq(1)
    end

    it "will award again if a year has passed" do
      user = Fabricate(:user, created_at: 800.days.ago)
      Fabricate(:post, user: user, created_at: 450.days.ago)

      freeze_time(400.days.ago) do
        granter.execute({})
      end

      badge = user.user_badges.where(badge_id: Badge::Anniversary)
      expect(badge.count).to eq(1)

      Fabricate(:post, user: user, created_at: 50.days.ago)
      granter.execute({})
      badge = user.user_badges.where(badge_id: Badge::Anniversary)
      expect(badge.count).to eq(2)
    end

    it "supports date ranges" do
      user = Fabricate(:user, created_at: 3.years.ago)
      Fabricate(:post, user: user, created_at: 750.days.ago)

      granter.execute(start_date: 800.days.ago)
      badge = user.user_badges.where(badge_id: Badge::Anniversary)
      expect(badge.count).to eq(1)

      Fabricate(:post, user: user, created_at: 50.days.ago)
      granter.execute(start_date: 800.days.ago)
      badge = user.user_badges.where(badge_id: Badge::Anniversary)
      expect(badge.count).to eq(1)

      granter.execute(start_date: 60.days.ago)
      badge = user.user_badges.where(badge_id: Badge::Anniversary)
      expect(badge.count).to eq(2)
    end
  end

end
