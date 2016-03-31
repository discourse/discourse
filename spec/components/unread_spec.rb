require 'rails_helper'
require 'unread'

describe Unread do


  before do
    @topic = Fabricate(:topic, posts_count: 13, highest_post_number: 13)
    @topic.notifier.watch_topic!(@topic.user_id)
    @topic_user = TopicUser.get(@topic, @topic.user)
    @topic_user.stubs(:notification_level).returns(TopicUser.notification_levels[:tracking])
    @topic_user.notification_level = TopicUser.notification_levels[:tracking]
    @unread = Unread.new(@topic, @topic_user)
  end

  describe 'unread_posts' do
    it 'should have 0 unread posts if the user has seen all posts' do
      @topic_user.stubs(:last_read_post_number).returns(13)
      @topic_user.stubs(:highest_seen_post_number).returns(13)
      expect(@unread.unread_posts).to eq(0)
    end

    it 'should have 6 unread posts if the user has seen all but 6 posts' do
      @topic_user.stubs(:last_read_post_number).returns(5)
      @topic_user.stubs(:highest_seen_post_number).returns(11)
      expect(@unread.unread_posts).to eq(6)
    end

    it 'should have 0 unread posts if the user has seen more posts than exist (deleted)' do
      @topic_user.stubs(:last_read_post_number).returns(100)
      @topic_user.stubs(:highest_seen_post_number).returns(13)
      expect(@unread.unread_posts).to eq(0)
    end
  end

  describe 'new_posts' do
    it 'should have 0 new posts if the user has read all posts' do
      @topic_user.stubs(:last_read_post_number).returns(13)
      expect(@unread.new_posts).to eq(0)
    end

    it 'returns 0 when the topic is the same length as when you last saw it' do
      @topic_user.stubs(:highest_seen_post_number).returns(13)
      expect(@unread.new_posts).to eq(0)
    end

    it 'has 3 new posts if the user has read 10 posts' do
      @topic_user.stubs(:highest_seen_post_number).returns(10)
      expect(@unread.new_posts).to eq(3)
    end

    it 'has 0 new posts if the user has read 10 posts but is not tracking' do
      @topic_user.stubs(:highest_seen_post_number).returns(10)
      @topic_user.stubs(:notification_level).returns(TopicUser.notification_levels[:regular])
      expect(@unread.new_posts).to eq(0)
    end

    it 'has 0 new posts if the user read more posts than exist (deleted)' do
      @topic_user.stubs(:highest_seen_post_number).returns(16)
      expect(@unread.new_posts).to eq(0)
    end

  end
end
