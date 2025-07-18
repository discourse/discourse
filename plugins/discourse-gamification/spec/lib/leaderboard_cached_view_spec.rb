# frozen_string_literal: true

require "rails_helper"

describe DiscourseGamification::LeaderboardCachedView do
  fab!(:admin)
  fab!(:user)
  fab!(:other_user) { Fabricate(:user) }
  fab!(:moderator)
  fab!(:leaderboard) { Fabricate(:gamification_leaderboard, created_by_id: admin.id) }
  fab!(:gamification_score) { Fabricate(:gamification_score, user_id: user.id, date: 8.days.ago) }

  let(:mviews) do
    DiscourseGamification::GamificationLeaderboard.periods.map do |period, _|
      "gamification_leaderboard_cache_#{leaderboard.id}_#{period}"
    end
  end

  let(:mview_count_query) { <<~SQL }
      SELECT
        count(*)
      FROM
        pg_matviews
      WHERE
        matviewname LIKE 'gamification_leaderboard_cache_#{leaderboard.id}_%'
    SQL

  let(:mview_names_query) { <<~SQL }
      SELECT
        matviewname
      FROM
        pg_matviews
      WHERE
        matviewname LIKE 'gamification_leaderboard_cache_#{leaderboard.id}_%'
    SQL

  describe "#create" do
    it "creates a leaderboard materialized view for each period" do
      described_class.new(leaderboard).create

      expect(DB.query_single(mview_count_query).first).to eq(6)
    end
  end

  describe "#refresh" do
    before do
      described_class.new(leaderboard).create
      Fabricate(:gamification_score, user_id: user.id, score: 10)
      Fabricate(:gamification_score, user_id: admin.id, score: 20)
      Fabricate(:gamification_score, user_id: other_user.id, score: 1, date: 5.days.ago)
      Fabricate(:gamification_score, user_id: other_user.id, score: 4, date: 3.days.ago)
    end

    it "refreshes leaderboard materialized views with the latest scores" do
      expect(DB.query_hash("SELECT * FROM #{mviews.first}")).to include(
        { "total_score" => 0, "user_id" => user.id, "position" => 1 },
      )

      described_class.new(leaderboard).refresh

      expect(DB.query_hash("SELECT * FROM #{mviews.first}")).to include(
        { "total_score" => 10, "user_id" => user.id, "position" => 2 },
        { "total_score" => 5, "user_id" => other_user.id, "position" => 3 },
        { "total_score" => 20, "user_id" => admin.id, "position" => 1 },
      )
    end
  end

  describe "#delete" do
    it "deletes all leaderboard materialized views" do
      cached_mview = described_class.new(leaderboard)
      cached_mview.create

      expect(DB.query_single(mview_count_query).first).to eq(6)

      cached_mview.delete

      expect(DB.query_single(mview_count_query).first).to eq(0)
    end
  end

  describe "#purge_stale" do
    it "removes all stale materialized views for leaderboard" do
      leaderboard_cache = described_class.new(leaderboard)

      leaderboard_cache.create
      expect(DB.query_single(mview_count_query).first).to eq(6)

      leaderboard_cache.purge_stale
      expect(DB.query_single(mview_count_query).first).to eq(6)

      # Update query to make existing materialized views stale
      allow(leaderboard_cache).to receive(
        :total_scores_query,
      ).and_wrap_original do |original_method, period|
        "#{original_method.call(period)} \n-- This is a new comment"
      end

      leaderboard_cache.purge_stale
      # Query changed, all existing stale materialized views removed
      expect(DB.query_single(mview_count_query).first).to eq(0)
    end

    it "does nothing if no stale materialized view exist for leaderboard" do
      described_class.new(leaderboard).create
      expect(DB.query_single(mview_names_query)).to contain_exactly(*mviews)

      described_class.new(leaderboard).purge_stale
      expect(DB.query_single(mview_names_query)).to contain_exactly(*mviews)
    end
  end

  describe "#scores" do
    let(:leaderboard_positions) { described_class.new(leaderboard) }
    let(:all_time_view_name) { "gamification_leaderboard_cache_#{leaderboard.id}_all_time" }

    context "when the materialized view exists in another schema" do
      before do
        DB.exec("CREATE SCHEMA IF NOT EXISTS test_backup")
        DB.exec(<<~SQL)
          CREATE MATERIALIZED VIEW test_backup.#{all_time_view_name} AS
          SELECT 1 AS user_id, 100 AS total_score, 1 AS position
        SQL
      end

      after { DB.exec("DROP SCHEMA IF EXISTS test_backup CASCADE") }

      it "raises NotReadyError" do
        expect { leaderboard_positions.scores(period: "all_time") }.to raise_error(
          DiscourseGamification::LeaderboardCachedView::NotReadyError,
        )
      end
    end

    context "with leaderboard dates" do
      let(:leaderboard_from) { Date.current - 45.days }
      let(:leaderboard_to) { Date.current - 15.days }

      before do
        [
          leaderboard_from - 15.days,
          leaderboard_from - 5.days,
          leaderboard_from - 1.day,
          leaderboard_from,
          Date.current - 1.month,
          leaderboard_to,
          leaderboard_to + 1.day,
          leaderboard_to + 15.days,
          leaderboard_to + 30.days,
        ].each { |date| Fabricate(:gamification_score, user_id: user.id, date: date, score: 10) }
      end

      it "filters scores for leaderboard with both 'from_date' and 'to_date' configured" do
        leaderboard.update!(from_date: leaderboard_from, to_date: leaderboard_to)
        leaderboard_positions.create

        expect(leaderboard_positions.scores.first&.total_score).to eq(30)
        expect(leaderboard_positions.scores(period: "yearly").first&.total_score).to eq(30)
        expect(leaderboard_positions.scores(period: "quarterly").first&.total_score).to eq(30)
        expect(leaderboard_positions.scores(period: "monthly").first&.total_score).to eq(20)
        expect(leaderboard_positions.scores(period: "weekly").first&.total_score).to be_nil
        expect(leaderboard_positions.scores(period: "daily").first&.total_score).to be_nil
      end

      it "filters scores for leaderboard with only 'from_date' configured" do
        leaderboard.update!(from_date: leaderboard_from)
        leaderboard_positions.create

        expect(leaderboard_positions.scores.first&.total_score).to eq(50)
        expect(leaderboard_positions.scores(period: "yearly").first&.total_score).to eq(50)
        expect(leaderboard_positions.scores(period: "quarterly").first&.total_score).to eq(50)
        expect(leaderboard_positions.scores(period: "monthly").first&.total_score).to eq(40)
        expect(leaderboard_positions.scores(period: "weekly").first&.total_score).to eq(10)
        expect(leaderboard_positions.scores(period: "daily").first&.total_score).to eq(10)
      end

      it "filters scores for leaderboard with only 'to_date' configured" do
        leaderboard.update!(to_date: leaderboard_to)
        leaderboard_positions.create

        expect(leaderboard_positions.scores.first&.total_score).to eq(60)
        expect(leaderboard_positions.scores(period: "yearly").first&.total_score).to eq(60)
        expect(leaderboard_positions.scores(period: "quarterly").first&.total_score).to eq(60)
        expect(leaderboard_positions.scores(period: "monthly").first&.total_score).to eq(20)
        expect(leaderboard_positions.scores(period: "weekly").first&.total_score).to be_nil
        expect(leaderboard_positions.scores(period: "daily").first&.total_score).to be_nil
      end

      it "filters scores for leaderboard with no dates configured" do
        leaderboard_positions.create

        expect(leaderboard_positions.scores.first&.total_score).to eq(80)
        expect(leaderboard_positions.scores(period: "yearly").first&.total_score).to eq(80)
        expect(leaderboard_positions.scores(period: "quarterly").first&.total_score).to eq(80)
        expect(leaderboard_positions.scores(period: "monthly").first&.total_score).to eq(40)
        expect(leaderboard_positions.scores(period: "weekly").first&.total_score).to eq(10)
        expect(leaderboard_positions.scores(period: "daily").first&.total_score).to eq(10)
      end
    end

    context "with leaderboard ranking strategies" do
      before do
        Fabricate(:gamification_score, user_id: user.id, score: 20)
        Fabricate(:gamification_score, user_id: admin.id, score: 50)
        Fabricate(:gamification_score, user_id: other_user.id, score: 20)
        Fabricate(:gamification_score, user_id: moderator.id, score: 10)
      end

      context "with 'rank'" do
        before do
          SiteSetting.score_ranking_strategy = "rank"

          described_class.new(leaderboard).create
        end

        it "returns ranked scores skipping the next rank after duplicates" do
          expect(leaderboard_positions.scores.map(&:attributes)).to eq(
            [
              {
                "total_score" => 50,
                "id" => admin.id,
                "position" => 1,
                "uploaded_avatar_id" => nil,
                "username" => admin.username,
                "name" => admin.name,
              },
              {
                "total_score" => 20,
                "id" => user.id,
                "position" => 2,
                "uploaded_avatar_id" => nil,
                "username" => user.username,
                "name" => user.name,
              },
              {
                "total_score" => 20,
                "id" => other_user.id,
                "position" => 2,
                "uploaded_avatar_id" => nil,
                "username" => other_user.username,
                "name" => other_user.name,
              },
              {
                "total_score" => 10,
                "id" => moderator.id,
                "position" => 4,
                "uploaded_avatar_id" => nil,
                "username" => moderator.username,
                "name" => moderator.name,
              },
            ],
          )
        end
      end

      context "with 'dense_rank'" do
        before do
          SiteSetting.score_ranking_strategy = "dense_rank"

          described_class.new(leaderboard).create
        end

        it "returns ranked scores without skipping the next rank after duplicates" do
          expect(leaderboard_positions.scores.map(&:attributes)).to eq(
            [
              {
                "total_score" => 50,
                "id" => admin.id,
                "position" => 1,
                "uploaded_avatar_id" => nil,
                "username" => admin.username,
                "name" => admin.name,
              },
              {
                "total_score" => 20,
                "id" => user.id,
                "position" => 2,
                "uploaded_avatar_id" => nil,
                "username" => user.username,
                "name" => user.name,
              },
              {
                "total_score" => 20,
                "id" => other_user.id,
                "position" => 2,
                "uploaded_avatar_id" => nil,
                "username" => other_user.username,
                "name" => other_user.name,
              },
              {
                "total_score" => 10,
                "id" => moderator.id,
                "position" => 3,
                "uploaded_avatar_id" => nil,
                "username" => moderator.username,
                "name" => moderator.name,
              },
            ],
          )
        end
      end

      context "with 'row_number'" do
        before do
          SiteSetting.score_ranking_strategy = "row_number"

          described_class.new(leaderboard).create
        end

        it "returns ranked scores without distinguishing duplicates" do
          expect(leaderboard_positions.scores.map(&:attributes)).to eq(
            [
              {
                "total_score" => 50,
                "id" => admin.id,
                "position" => 1,
                "uploaded_avatar_id" => nil,
                "username" => admin.username,
                "name" => admin.name,
              },
              {
                "total_score" => 20,
                "id" => user.id,
                "position" => 2,
                "uploaded_avatar_id" => nil,
                "username" => user.username,
                "name" => user.name,
              },
              {
                "total_score" => 20,
                "id" => other_user.id,
                "position" => 3,
                "uploaded_avatar_id" => nil,
                "username" => other_user.username,
                "name" => other_user.name,
              },
              {
                "total_score" => 10,
                "id" => moderator.id,
                "position" => 4,
                "uploaded_avatar_id" => nil,
                "username" => moderator.username,
                "name" => moderator.name,
              },
            ],
          )
        end
      end
    end
  end
end
