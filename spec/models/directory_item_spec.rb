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
      UserActionCreator.enable
    end

    it "creates the record for the user" do
      post = create_post
      DirectoryItem.refresh!
      expect(DirectoryItem.where(period_type: DirectoryItem.period_types[:all])
                          .where(user_id: post.user.id)
                          .where(topic_count: 1).count).to eq(1)
    end

    it "handles users with no activity" do
      post = nil

      freeze_time(2.years.ago) do
        post = create_post
        # Create records for that activity
        DirectoryItem.refresh!
      end

      DirectoryItem.refresh!
      [:yearly, :monthly, :weekly, :daily, :quarterly].each do |period|
        directory_item = DirectoryItem
          .where(period_type: DirectoryItem.period_types[period])
          .where(user_id: post.user.id)
          .first
        expect(directory_item.topic_count).to eq(0)
        expect(directory_item.post_count).to eq(0)
      end

      directory_item = DirectoryItem
        .where(period_type: DirectoryItem.period_types[:all])
        .where(user_id: post.user.id)
        .first
      expect(directory_item.topic_count).to eq(1)
    end

  end
end
