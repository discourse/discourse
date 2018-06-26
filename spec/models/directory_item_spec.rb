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

  context 'inactive and silenced users' do
    it 'removes silenced users correctly' do
      post = create_post
      DirectoryItem.refresh_period!(:daily)

      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(1)

      post.user.update_columns(active: false)
      DirectoryItem.refresh_period!(:daily)

      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(0)

      post.user.update_columns(active: true)
      DirectoryItem.refresh_period!(:daily)

      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(1)

      post.user.update_columns(silenced_till: 1.year.from_now)
      DirectoryItem.refresh_period!(:daily)

      count = DirectoryItem.where(user_id: post.user_id).count
      expect(count).to eq(0)

    end
  end

  context 'refresh' do
    before do
      UserActionCreator.enable
    end

    it "creates the record for the user and handles likes" do
      post = create_post
      _post2 = create_post(topic_id: post.topic_id, user: post.user)

      user2 = Fabricate(:user)

      PostAction.act(user2, post, PostActionType.types[:like])

      DirectoryItem.refresh!

      item1 = DirectoryItem.find_by(period_type: DirectoryItem.period_types[:all], user_id: post.user_id)
      item2 = DirectoryItem.find_by(period_type: DirectoryItem.period_types[:all], user_id: user2.id)

      expect(item1.topic_count).to eq(1)
      expect(item1.likes_received).to eq(1)
      expect(item1.post_count).to eq(1)

      expect(item2.likes_given).to eq(1)

      post.topic.trash!

      DirectoryItem.refresh!

      item1 = DirectoryItem.find_by(period_type: DirectoryItem.period_types[:all], user_id: post.user_id)
      item2 = DirectoryItem.find_by(period_type: DirectoryItem.period_types[:all], user_id: user2.id)

      expect(item1.likes_given).to eq(0)
      expect(item1.likes_received).to eq(0)
      expect(item1.post_count).to eq(0)
      expect(item1.topic_count).to eq(0)
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
