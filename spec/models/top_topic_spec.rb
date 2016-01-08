require 'rails_helper'

describe TopTopic do

  describe '#sorted_periods' do
    context "verify enum sequence" do
      before do
        @sorted_periods = TopTopic.sorted_periods
      end

      it "'daily' should be at 1st position" do
        expect(@sorted_periods[:daily]).to eq(1)
      end

      it "'all' should be at 6th position" do
        expect(@sorted_periods[:all]).to eq(6)
      end
    end
  end

  it { is_expected.to belong_to :topic }

  context "refresh!" do

    let!(:t1) { Fabricate(:topic) }
    let!(:t2) { Fabricate(:topic) }

    it "begins blank" do
      expect(TopTopic.all).to be_blank
    end

    context "after calculating" do

      before do
        TopTopic.refresh!
      end

      it "should have top topics" do
        expect(TopTopic.pluck(:topic_id)).to match_array([t1.id, t2.id])
      end

    end

  end

end
