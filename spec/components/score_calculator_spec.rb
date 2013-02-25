require 'spec_helper'
require 'score_calculator'

describe ScoreCalculator do

  before do
    @post = Fabricate(:post, reads: 111)
    @topic = @post.topic
  end

  context 'with weightings' do
    before do
      ScoreCalculator.new(reads: 3).calculate
      @post.reload
    end

    it 'takes the supplied weightings into effect' do
      @post.score.should == 333
    end
  end

  context 'best_of' do

    it "won't update the site settings when the site settings don't match" do
      ScoreCalculator.new(reads: 3).calculate
      @topic.reload
      @topic.has_best_of.should be_false
    end

    it "removes the best_of flag if the topic no longer qualifies" do
      @topic.update_column(:has_best_of, true)
      ScoreCalculator.new(reads: 3).calculate
      @topic.reload
      @topic.has_best_of.should be_false
    end

    it "won't update the site settings when the site settings don't match" do
      SiteSetting.expects(:best_of_likes_required).returns(0)
      SiteSetting.expects(:best_of_posts_required).returns(1)
      SiteSetting.expects(:best_of_score_threshold).returns(100)

      ScoreCalculator.new(reads: 3).calculate
      @topic.reload
      @topic.has_best_of.should be_true
    end

  end

end
