require 'rails_helper'

describe TopTopic do

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
