require 'spec_helper'
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
      post.score.should == 333
      another_post.score.should == 666
    end

    it "creates the percent_ranks" do
      another_post.percent_rank.should == 0.0
      post.percent_rank.should == 1.0
    end

    it "gives the topic a score" do
      topic.score.should be_present
    end

    it "gives the topic a percent_rank" do
      topic.percent_rank.should_not == 1.0
    end

  end

  context 'summary' do

    it "won't update the site settings when the site settings don't match" do
      ScoreCalculator.new(reads: 3).calculate
      topic.reload
      topic.has_summary.should be_false
    end

    it "removes the summary flag if the topic no longer qualifies" do
      topic.update_column(:has_summary, true)
      ScoreCalculator.new(reads: 3).calculate
      topic.reload
      topic.has_summary.should be_false
    end

    it "won't update the site settings when the site settings don't match" do
      SiteSetting.expects(:summary_likes_required).returns(0)
      SiteSetting.expects(:summary_posts_required).returns(1)
      SiteSetting.expects(:summary_score_threshold).returns(100)

      ScoreCalculator.new(reads: 3).calculate
      topic.reload
      topic.has_summary.should be_true
    end

  end

end
