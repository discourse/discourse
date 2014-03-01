require 'spec_helper'

describe TopTopic do

  it { should belong_to :topic }

  context "refresh!" do

    let!(:t1) { Fabricate(:topic) }
    let!(:t2) { Fabricate(:topic) }

    it "begins blank" do
      TopTopic.all.should be_blank
    end

    context "after calculating" do

      before do
        TopTopic.refresh!
      end

      it "should have top topics" do
        TopTopic.pluck(:topic_id).should =~ [t1.id, t2.id]
      end

    end

  end

end
