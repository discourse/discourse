require 'rails_helper'

describe DirectoryItem do

  describe '#period_types' do
    context "verify enum sequence" do
      before do
        @period_types = DirectoryItem.period_types
      end

      it "'all' should be at 1st position" do
        expect(@period_types[:all]).to eq(1)
      end

      it "'quarterly' should be at 6th position" do
        expect(@period_types[:quarterly]).to eq(6)
      end
    end
  end

  context 'refresh' do
    before do
      ActiveRecord::Base.observers.enable :all
    end

    let!(:post) { create_post }

    it "creates the record for the user" do
      DirectoryItem.refresh!
      expect(DirectoryItem.where(period_type: DirectoryItem.period_types[:all])
                          .where(user_id: post.user.id)
                          .where(topic_count: 1).count).to eq(1)
    end

  end
end
