# frozen_string_literal: true

require 'rails_helper'
require 'unread'

describe Unread do

  let (:user) { Fabricate.build(:user, id: 1) }
  let (:topic) do
    Fabricate.build(:topic,
                       posts_count: 13,
                       highest_staff_post_number: 15,
                       highest_post_number: 13,
                       id: 1)
  end

  let (:topic_user) do
    Fabricate.build(:topic_user,
                        notification_level: TopicUser.notification_levels[:tracking],
                        topic_id: topic.id,
                        user_id: user.id)
  end

  def unread
    Unread.new(topic, topic_user, Guardian.new(user))
  end

  describe 'staff counts' do
    it 'should correctly return based on staff post number' do
      user.admin = true

      topic_user.last_read_post_number = 13

      expect(unread.unread_posts).to eq(2)
    end
  end

  describe 'unread_posts' do
    it 'should have 0 unread posts if the user has read all posts' do
      topic_user.last_read_post_number = 13
      expect(unread.unread_posts).to eq(0)
    end

    it 'returns the right unread posts for a user' do
      topic_user.last_read_post_number = 10
      expect(unread.unread_posts).to eq(3)
    end

    it 'returns the right unread posts for a staff user' do
      user.admin = true
      topic_user.last_read_post_number = 10
      expect(unread.unread_posts).to eq(5)
    end

    it 'should have 0 unread posts if the user has read more posts than exist (deleted)' do
      topic_user.last_read_post_number = 14
      expect(unread.unread_posts).to eq(0)
    end

    it 'has 0 unread posts if the user has read 10 posts but is not tracking' do
      topic_user.last_read_post_number = 10
      topic_user.notification_level = TopicUser.notification_levels[:regular]
      expect(unread.unread_posts).to eq(0)
    end

    it 'has 0 unread psots if the user has not seen the topic' do
      topic_user.last_read_post_number = nil
      expect(unread.unread_posts).to eq(0)
    end
  end

end
