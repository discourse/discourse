require 'rails_helper'
require 'score_calculator'

describe ScoreCalculator do

  let!(:post) { Fabricate(:post, reads: 111) }
  let!(:another_post) { Fabricate(:post, topic: post.topic, reads: 222) }
  let(:topic) { post.topic }

  context 'with weightings' do
    before do
      ScoreCalculator.new(reads: 3).calculate
      post.reload
      another_post.reload
    end

    it 'takes the supplied weightings into effect' do
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

    it "gives the topic a percent_rank" do
      expect(topic.percent_rank).not_to eq(1.0)
    end

  end

  context 'summary' do

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
