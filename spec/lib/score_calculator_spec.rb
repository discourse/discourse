# frozen_string_literal: true

require "score_calculator"

RSpec.describe ScoreCalculator do
  fab!(:post) { Fabricate(:post, reads: 111) }
  fab!(:another_post) { Fabricate(:post, topic: post.topic, reads: 222) }
  let(:topic) { post.topic }

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
    it "leaves the summary flag unset when the topic does not qualify" do
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

    it "sets the summary flag when the topic meets the configured thresholds" do
      SiteSetting.expects(:summary_likes_required).returns(0)
      SiteSetting.expects(:summary_posts_required).returns(1)
      SiteSetting.expects(:summary_score_threshold).returns(100)

      ScoreCalculator.new(reads: 3).calculate
      topic.reload
      expect(topic.has_summary).to eq(true)
    end
  end

  describe "topic batches" do
    it "ranks complete topics independently across batches, including tied scores" do
      tied_post = Fabricate(:post, topic: topic, reads: 222)
      other_post = Fabricate(:post, reads: 10)
      other_reply = Fabricate(:post, topic: other_post.topic, reads: 30)
      empty_topic = Fabricate(:topic, score: 123)

      stub_const(ScoreCalculator, :TOPIC_BATCH_SIZE, 1) { ScoreCalculator.new(reads: 3).calculate }

      expect([post, another_post, tied_post].map { |p| p.reload.score }).to eq([333, 666, 666])
      expect([post, another_post, tied_post].map(&:percent_rank)).to eq([1.0, 0.0, 0.0])
      expect(topic.reload.score).to eq(555)
      expect(other_post.reload.percent_rank).to eq(1.0)
      expect(other_reply.reload.percent_rank).to eq(0.0)
      expect(other_post.topic.reload.score).to eq(60)
      expect(empty_topic.reload.score).to eq(123)
    end

    it "leaves all scores and ranks of excluded topics unchanged" do
      old_post = Fabricate(:post, reads: 10, score: 17, percent_rank: 0.75)
      long_post = Fabricate(:post, reads: 20, score: 19, percent_rank: 0.25)
      old_post.topic.update_columns(bumped_at: 1.month.ago, score: 23, has_summary: true)
      long_post.topic.update_columns(posts_count: 500, score: 29, has_summary: true)
      topic.update_columns(bumped_at: Time.current, posts_count: 2)

      ScoreCalculator.new(reads: 3).calculate(min_topic_age: 1.day.ago, max_topic_length: 500)

      expect(post.reload.score).to eq(333)
      expect(another_post.reload.percent_rank).to eq(0.0)
      expect(topic.reload.score).to eq(499.5)
      expect(old_post.reload.attributes.values_at("score", "percent_rank")).to eq([17, 0.75])
      expect(long_post.reload.attributes.values_at("score", "percent_rank")).to eq([19, 0.25])
      expect(old_post.topic.reload.attributes.values_at("score", "has_summary")).to eq([23, true])
      expect(long_post.topic.reload.attributes.values_at("score", "has_summary")).to eq([29, true])
    end

    it "continues to include deleted topics and posts" do
      topic.update_column(:deleted_at, Time.current)
      another_post.update_column(:deleted_at, Time.current)

      ScoreCalculator.new(reads: 3).calculate

      expect(another_post.reload.score).to eq(666)
      expect(another_post.percent_rank).to eq(0.0)
      expect(post.reload.percent_rank).to eq(1.0)
      expect(topic.reload.score).to eq(499.5)
    end

    it "does not update posts or topics when no topics match" do
      queries = track_sql_queries { ScoreCalculator.new(reads: 3).calculate(max_topic_length: 0) }

      expect(queries.grep(/UPDATE (posts|topics)/i)).to be_empty
    end
  end
end
