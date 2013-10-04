require 'spec_helper'
require_dependency 'jobs/scheduled/periodical_updates'

describe Jobs::PeriodicalUpdates do

  after do
    Jobs::PeriodicalUpdates.new.execute(nil)
  end

  it "calculates avg post time" do
    Post.expects(:calculate_avg_time).once
  end

  it "calculates avg topic time" do
    Topic.expects(:calculate_avg_time).once
  end

  it "features topics" do
    CategoryFeaturedTopic.expects(:feature_topics).once
  end

  it "updates view counts" do
    UserStat.expects(:update_view_counts).once
  end

  it "calculates scores" do
    calculator = mock()
    ScoreCalculator.expects(:new).once.returns(calculator)
    calculator.expects(:calculate)
  end

  it "refreshes hot topics" do
    HotTopic.expects(:refresh!).once
  end

end
