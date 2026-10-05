# frozen_string_literal: true

require "score_calculator"

RSpec.describe ScoreCalculator do
  fab!(:post) { Fabricate(:post, reads: 111) }
  fab!(:another_post) { Fabricate(:post, topic: post.topic, reads: 222) }
  let(:topic) { post.topic }

  describe "#calculate" do
    it "ranks every post in an eligible topic without changing excluded topics" do
      cutoff = 1.day.ago
      old_post = Fabricate(:post, topic: topic, reads: 333)
      old_post.update_columns(created_at: 1.year.ago, percent_rank: nil)
      post.update_column(:percent_rank, nil)
      another_post.update_column(:percent_rank, nil)
      topic.update_column(:bumped_at, cutoff + 1.second)

      old_topic_post = Fabricate(:post, reads: 999, percent_rank: 0.25)
      old_topic_post.topic.update_column(:bumped_at, cutoff)
      long_topic_post = Fabricate(:post, reads: 999, percent_rank: 0.25)
      long_topic_post.topic.update_column(:posts_count, 500)

      ScoreCalculator.new(reads: 1).calculate(min_topic_age: cutoff, max_topic_length: 500)

      expect(
        [old_post.reload.percent_rank, another_post.reload.percent_rank, post.reload.percent_rank],
      ).to eq([0.0, 0.5, 1.0])
      expect([old_topic_post.reload.percent_rank, long_topic_post.reload.percent_rank]).to eq(
        [0.25, 0.25],
      )
      expect([old_topic_post.topic.reload.score, long_topic_post.topic.reload.score]).to eq(
        [nil, nil],
      )
    end

    it "gives tied scores the same rank and calculates the average across all topic posts" do
      third_post = Fabricate(:post, topic: topic, reads: 222)
      topic.update_columns(score: nil, like_count: 2, posts_count: 3)
      SiteSetting.stubs(:summary_likes_required).returns(2)
      SiteSetting.stubs(:summary_posts_required).returns(3)
      SiteSetting.stubs(:summary_score_threshold).returns(222)

      ScoreCalculator.new(reads: 1).calculate(min_topic_age: 1.day.ago)

      expect(
        [
          another_post.reload.percent_rank,
          third_post.reload.percent_rank,
          post.reload.percent_rank,
        ],
      ).to eq([0.0, 0.0, 1.0])
      expect(topic.reload.score).to eq(185)
      expect(topic.has_summary).to eq(true)

      SiteSetting.stubs(:summary_score_threshold).returns(223)
      ScoreCalculator.new(reads: 1).calculate(min_topic_age: 1.day.ago)
      expect(topic.reload.has_summary).to eq(false)
    end

    it "recalculates excluded topics when called without filters" do
      topic.update_columns(bumped_at: 1.year.ago, posts_count: 500, score: nil)
      post.update_column(:percent_rank, nil)
      another_post.update_column(:percent_rank, nil)

      ScoreCalculator.new(reads: 1).calculate

      expect([another_post.reload.percent_rank, post.reload.percent_rank]).to eq([0.0, 1.0])
      expect(topic.reload.score).to eq(166.5)
    end
  end

  context "with weightings" do
    before do
      ScoreCalculator.new(reads: 3).calculate
      post.reload
      another_post.reload
    end

    it "takes the supplied weightings into effect" do
      expect(post.score).to eq(333)
      expect(another_post.score).to eq(666)
    end

    it "creates the percent_ranks" do
      expect(another_post.percent_rank).to eq(0.0)
      expect(post.percent_rank).to eq(1.0)
    end

    it "gives the topic a score" do
      expect(topic.score).to be_present
    end
  end

  describe "summary" do
    it "won't update the site settings when the site settings don't match" do
      ScoreCalculator.new(reads: 3).calculate
      topic.reload
      expect(topic.has_summary).to eq(false)
    end

    it "removes the summary flag if the topic no longer qualifies" do
      topic.update_column(:has_summary, true)
      ScoreCalculator.new(reads: 3).calculate
      topic.reload
      expect(topic.has_summary).to eq(false)
    end

    it "respects the min_topic_age" do
      topic.update_columns(has_summary: true, bumped_at: 1.month.ago)
      ScoreCalculator.new(reads: 3).calculate(min_topic_age: 20.days.ago)
      expect(topic.has_summary).to eq(true)
    end

    it "respects the max_topic_length" do
      Fabricate(:post, topic_id: topic.id)
      topic.update_columns(has_summary: true)
      ScoreCalculator.new(reads: 3).calculate(max_topic_length: 1)
      expect(topic.has_summary).to eq(true)
    end

    it "won't update the site settings when the site settings don't match" do
      SiteSetting.expects(:summary_likes_required).returns(0)
      SiteSetting.expects(:summary_posts_required).returns(1)
      SiteSetting.expects(:summary_score_threshold).returns(100)

      ScoreCalculator.new(reads: 3).calculate
      topic.reload
      expect(topic.has_summary).to eq(true)
    end
  end
end
