require 'spec_helper'
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
      @topic_user.stubs(:seen_post_count).returns(13)
      @unread.unread_posts.should == 0
    end

    it 'should have 6 unread posts if the user has seen all but 6 posts' do
      @topic_user.stubs(:last_read_post_number).returns(5)
      @topic_user.stubs(:seen_post_count).returns(11)
      @unread.unread_posts.should == 6
    end

    it 'should have 0 unread posts if the user has seen more posts than exist (deleted)' do
      @topic_user.stubs(:last_read_post_number).returns(100)
      @topic_user.stubs(:seen_post_count).returns(13)
      @unread.unread_posts.should == 0
    end
  end

  describe 'new_posts' do
    it 'should have 0 new posts if the user has read all posts' do
      @topic_user.stubs(:last_read_post_number).returns(13)
      @unread.new_posts.should == 0
    end

    it 'returns 0 when the topic is the same length as when you last saw it' do
      @topic_user.stubs(:seen_post_count).returns(13)
      @unread.new_posts.should == 0
    end

    it 'has 3 new posts if the user has read 10 posts' do
      @topic_user.stubs(:seen_post_count).returns(10)
      @unread.new_posts.should == 3
    end

    it 'has 0 new posts if the user has read 10 posts but is not tracking' do
      @topic_user.stubs(:seen_post_count).returns(10)
      @topic_user.stubs(:notification_level).returns(TopicUser.notification_levels[:regular])
      @unread.new_posts.should == 0
    end

    it 'has 0 new posts if the user read more posts than exist (deleted)' do
      @topic_user.stubs(:seen_post_count).returns(16)
      @unread.new_posts.should == 0
    end

  end
end
