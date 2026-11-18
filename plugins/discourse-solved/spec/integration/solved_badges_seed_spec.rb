# frozen_string_literal: true

RSpec.describe "Solved badge seeds" do
  let(:badge_names) { ["Solved 1", "Solved 2", "Solved 3", "Solved 4"] }

  it "keeps the stock queries and descriptions unless the count is configured" do
    badge = Badge.find_by!(name: "Solved 2")
    original_description = I18n.t("badges.solved_2.description")

    expect(badge.query).to eq(DiscourseSolved::Queries.solved_badge_query(10))
    expect(badge.description).to eq(original_description)

    SiteSetting.solved_badge_2_required_solutions = 3
    load Rails.root.join("plugins/discourse-solved/db/fixtures/001_badges.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative

    expect(badge.reload[:query]).to eq(DiscourseSolved::Queries.solved_badge_query(10))
    expect(badge.query).to eq(DiscourseSolved::Queries.solved_badge_query(3))
    expect(badge.description).to eq(I18n.t("badges.solved_threshold", count: 3))
    expect(badge.long_description).to eq(badge.description)
    expect(Badge.find_by!(name: "Solved 3").query).to eq(
      DiscourseSolved::Queries.solved_badge_query(50),
    )

    SiteSetting.solved_badge_2_required_solutions = 10

    expect(badge.query).to eq(DiscourseSolved::Queries.solved_badge_query(10))
    expect(badge.description).to eq(original_description)
  end

  it "uses the configured threshold when granting and revoking a Solved badge" do
    badge = Badge.find_by!(name: "Solved 4")
    question = Fabricate(:post)
    answer = Fabricate(:post, topic: question.topic)
    solved = DiscourseSolved::SolvedTopic.create!(topic: question.topic)
    DiscourseSolved::TopicAnswer.create!(
      solved_topic: solved,
      post: answer,
      accepter: question.topic.user,
    )
    SiteSetting.solved_badge_4_required_solutions = 1

    BadgeGranter.backfill(badge)

    expect(UserBadge.exists?(badge: badge, user: answer.user)).to eq(true)

    SiteSetting.solved_badge_4_required_solutions = 150
    BadgeGranter.backfill(badge)

    expect(UserBadge.exists?(badge: badge, user: answer.user)).to eq(false)
  end

  describe "seeding the Solved badges on a new site" do
    it "enables the badges by default" do
      Badge.where(name: badge_names).delete_all
      load Rails.root.join("plugins/discourse-solved/db/fixtures/001_badges.rb") # rubocop:disable Discourse/Plugins/UseRequireRelative

      expect(Badge.where(name: badge_names).pluck(:enabled)).to all(eq(true))
    end
  end
end
