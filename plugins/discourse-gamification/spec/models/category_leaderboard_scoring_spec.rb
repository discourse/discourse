# frozen_string_literal: true

RSpec.describe DiscourseGamification::GamificationLeaderboardScore, type: :model do
  fab!(:user)
  fab!(:building_category, :category)
  fab!(:building_tools_category, :category)
  fab!(:feedback_category, :category)
  fab!(:ux_reports_category, :category)
  fab!(:general_bugs_category, :category)
  fab!(:support_category, :category)

  fab!(:builders) do
    Fabricate(
      :gamification_leaderboard,
      name: "Builders",
      scorable_category_ids: [building_category.id, building_tools_category.id],
    )
  end
  fab!(:help) do
    Fabricate(
      :gamification_leaderboard,
      name: "Help",
      scorable_category_ids: [
        feedback_category.id,
        ux_reports_category.id,
        general_bugs_category.id,
      ],
    )
  end
  fab!(:support) do
    Fabricate(
      :gamification_leaderboard,
      name: "Support",
      scorable_category_ids: [support_category.id],
    )
  end

  before do
    today = DB.query_single("SELECT CURRENT_DATE").first
    freeze_time Time.utc(today.year, today.month, today.day, 12)

    [building_category, building_tools_category].each do |category|
      Fabricate(:topic, user: user, category: category)
    end

    20.times do
      topic = Fabricate(:topic, user: user, category: support_category)
      Fabricate(:post, user: user, topic: topic, post_number: 2)
    end
  end

  def calculate_and_read_scores(for_user, since_date: Date.current, period: "all_time")
    [builders, help, support].map do |leaderboard|
      described_class.calculate_scores(leaderboard, since_date: since_date)
      cache = DiscourseGamification::LeaderboardCachedView.new(leaderboard)
      cache.delete
      cache.create
      cache.scores(for_user_id: for_user.id, period: period).first&.total_score
    end
  end

  describe ".calculate_scores" do
    it "keeps heavy support topic and reply scores out of the other category leaderboards" do
      expect(calculate_and_read_scores(user)).to eq([10, nil, 140])
    end

    it "excludes global activity when category activity is older than the weekly window" do
      today = DB.query_single("SELECT CURRENT_DATE").first
      activity_date = today - 10
      user.topics.update_all(created_at: activity_date)
      user.posts.update_all(created_at: activity_date)
      Fabricate(:user_visit, user: user, visited_at: today, time_read: 7200, posts_read: 300)

      expect(calculate_and_read_scores(user, since_date: activity_date, period: "weekly")).to eq(
        [nil, nil, nil],
      )
      expect(calculate_and_read_scores(user, since_date: activity_date)).to eq([10, nil, 140])
    end

    it "excludes visit, reading, and uncategorized manual points from category leaderboards" do
      Fabricate(:user_visit, user: user, time_read: 7200, posts_read: 300)

      expect(calculate_and_read_scores(user)).to eq([10, nil, 140])

      DiscourseGamification::GamificationScoreEvent.create!(
        user: user,
        date: Date.current,
        points: 1000,
      )

      expect(calculate_and_read_scores(user)).to eq([10, nil, 140])

      global = Fabricate(:gamification_leaderboard)
      described_class.calculate_scores(global)
      cache = DiscourseGamification::LeaderboardCachedView.new(global)
      cache.create
      expect(cache.scores(for_user_id: user.id).first.total_score).to eq(1156)

      visitor = Fabricate(:user)
      Fabricate(:user_visit, user: visitor, time_read: 7200, posts_read: 300)

      expect(calculate_and_read_scores(visitor)).to eq([nil, nil, nil])
    end

    it "counts manual points only on leaderboards scoped to their category" do
      [
        { points: 1000, category_id: nil },
        { points: 50, category_id: support_category.id },
        { points: 7, category_id: building_tools_category.id },
        { points: -3, category_id: building_category.id },
      ].each do |attrs|
        DiscourseGamification::GamificationScoreEvent.create!(
          user: user,
          date: Date.current,
          **attrs,
        )
      end

      expect(calculate_and_read_scores(user)).to eq([14, nil, 190])

      global = Fabricate(:gamification_leaderboard)
      described_class.calculate_scores(global)

      expect(global.leaderboard_scores.where(user: user).sum(:score)).to eq(1204)
    end

    it "filters categorized manual points by the site category setting on global leaderboards" do
      SiteSetting.scorable_categories = support_category.id.to_s
      [
        { points: 1000, category_id: nil },
        { points: 50, category_id: support_category.id },
        { points: 7, category_id: building_category.id },
      ].each do |attrs|
        DiscourseGamification::GamificationScoreEvent.create!(
          user: user,
          date: Date.current,
          **attrs,
        )
      end

      global = Fabricate(:gamification_leaderboard)
      described_class.calculate_scores(global)

      expect(global.leaderboard_scores.where(user: user).sum(:score)).to eq(1190)
    end

    it "ignores blank entries in the category list" do
      support.update!(scorable_category_ids: [support_category.id, nil])
      DiscourseGamification::GamificationScoreEvent.create!(
        user: user,
        date: Date.current,
        points: 50,
        category_id: support_category.id,
      )

      expect(calculate_and_read_scores(user).last).to eq(190)
    end

    it "excludes visitors with zero points from category leaderboards" do
      visitor = Fabricate(:user)
      Fabricate(:user_visit, user: visitor, time_read: 60, posts_read: 5)
      [builders, help, support].each do |leaderboard|
        leaderboard.update!(score_overrides: { "day_visited" => 0 })
      end

      expect(calculate_and_read_scores(visitor)).to eq([nil, nil, nil])
    end

    it "excludes invitations, flags, and chat activity even with positive score overrides" do
      SiteSetting.chat_enabled = true
      Fabricate(:invite, invited_by: user, redemption_count: 1)
      Fabricate(:reviewable, created_by: user, status: Reviewable.statuses[:approved])
      other_user = Fabricate(:user)
      message = Fabricate(:chat_message, user: user)
      other_message = Fabricate(:chat_message, user: other_user)
      Fabricate(:chat_message_reaction, chat_message: message, user: other_user)
      Fabricate(:chat_message_reaction, chat_message: other_message, user: user)
      [builders, help, support].each do |leaderboard|
        leaderboard.update!(
          score_overrides: {
            "user_invited" => 100,
            "flag_created" => 100,
            "chat_message_created" => 100,
            "chat_reaction_given" => 100,
            "chat_reaction_received" => 100,
          },
        )
      end

      expect(calculate_and_read_scores(user)).to eq([10, nil, 140])
    end

    it "preserves global activity and manual points when inheriting the site category filter" do
      SiteSetting.scorable_categories = support_category.id.to_s
      Fabricate(:user_visit, user: user, time_read: 7200, posts_read: 300)
      DiscourseGamification::GamificationScoreEvent.create!(
        user: user,
        date: Date.current,
        points: 1000,
      )

      global = Fabricate(:gamification_leaderboard)
      described_class.calculate_scores(global)

      expect(global.leaderboard_scores.where(user: user).sum(:score)).to eq(1146)
      expect(calculate_and_read_scores(user)).to eq([10, nil, 140])

      global.update!(scorable_category_ids: [])
      described_class.calculate_scores(global)

      expect(global.leaderboard_scores.where(user: user).sum(:score)).to eq(1156)
    end

    it "clears stale scores when all category-based sources are disabled" do
      help.update!(
        score_overrides: {
          "topic_created" => 0,
          "post_created" => 0,
          "like_given" => 0,
          "like_received" => 0,
          "reaction_given" => 0,
          "reaction_received" => 0,
          "solution" => 0,
        },
      )
      help.leaderboard_scores.create!(user: user, date: Date.current, score: 1000)
      DiscourseGamification::GamificationScoreEvent.create!(
        user: user,
        date: Date.current,
        points: 1000,
      )

      described_class.calculate_scores(help)

      expect(help.leaderboard_scores.where(user: user)).to be_empty
    end

    it "removes historical global points with a full leaderboard recalculation" do
      activity_date = DB.query_single("SELECT CURRENT_DATE").first - 30
      [builders, help, support].each do |leaderboard|
        leaderboard.leaderboard_scores.create!(user: user, date: activity_date, score: 1000)

        Jobs::RecalculateLeaderboardScores.new.execute(leaderboard_id: leaderboard.id)
      end

      scores =
        [builders, help, support].map do |leaderboard|
          DiscourseGamification::GamificationLeaderboard
            .scores_for(leaderboard.id, for_user_id: user.id)
            .first
            &.total_score
        end

      expect(scores).to eq([10, nil, 140])
    end
  end
end
