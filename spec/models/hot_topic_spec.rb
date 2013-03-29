require 'spec_helper'

describe HotTopic do

  it { should belong_to :topic }
  it { should belong_to :category }


  context "refresh!" do

    let!(:t1) { Fabricate(:topic) }
    let!(:t2) { Fabricate(:topic) }

    it "begins blank" do
      HotTopic.all.should be_blank
    end

    context "after calculating" do

      before do
        # Calculate the scores before we calculate hot
        ScoreCalculator.new.calculate
        HotTopic.refresh!
      end

      it "should have hot topics" do
        HotTopic.pluck(:topic_id).should =~ [t1.id, t2.id]
      end

    end

  end

end
