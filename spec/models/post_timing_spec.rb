# frozen_string_literal: true

require 'rails_helper'

describe PostTiming do

  it { is_expected.to validate_presence_of :post_number }
  it { is_expected.to validate_presence_of :msecs }

  describe 'pretend_read' do
    fab!(:p1) { Fabricate(:post) }
    fab!(:p2) { Fabricate(:post, topic: p1.topic, user: p1.user) }
    fab!(:p3) { Fabricate(:post, topic: p1.topic, user: p1.user) }

    let :topic_id do
      p1.topic_id
    end

    def timing(user_id, post_number)
      PostTiming.create!(topic_id: topic_id, user_id: user_id, post_number: post_number, msecs: 0)
    end

    def topic_user(user_id, last_read_post_number, highest_seen_post_number)
      TopicUser.create!(
                        topic_id: topic_id,
                        user_id: user_id,
                        last_read_post_number: last_read_post_number,
                        highest_seen_post_number: highest_seen_post_number
                       )
    end

    it 'works correctly' do
      timing(1, 1)
      timing(2, 1)
      timing(2, 2)
      timing(3, 1)
      timing(3, 2)
      timing(3, 3)

      _tu_one = topic_user(1, 1, 1)
      _tu_two = topic_user(2, 2, 2)
      _tu_three = topic_user(3, 3, 3)

      PostTiming.pretend_read(topic_id, 2, 3)

      expect(PostTiming.where(topic_id: topic_id, user_id: 1, post_number: 3).count).to eq(0)
      expect(PostTiming.where(topic_id: topic_id, user_id: 2, post_number: 3).count).to eq(1)
      expect(PostTiming.where(topic_id: topic_id, user_id: 3, post_number: 3).count).to eq(1)

      tu = TopicUser.find_by(topic_id: topic_id, user_id: 1)
      expect(tu.last_read_post_number).to eq(1)
      expect(tu.highest_seen_post_number).to eq(1)

      tu = TopicUser.find_by(topic_id: topic_id, user_id: 2)
      expect(tu.last_read_post_number).to eq(3)
      expect(tu.highest_seen_post_number).to eq(3)

      tu = TopicUser.find_by(topic_id: topic_id, user_id: 3)
      expect(tu.last_read_post_number).to eq(3)
      expect(tu.highest_seen_post_number).to eq(3)

    end
  end

  describe 'safeguard' do
    it "doesn't store timings that are larger than the account lifetime" do
      user = Fabricate(:user, created_at: 3.minutes.ago)
      post = Fabricate(:post)

      PostTiming.process_timings(user, post.topic_id, 1, [[post.post_number, 123]])
      msecs = PostTiming.where(post_number: post.post_number, user_id: user.id).pluck(:msecs)[0]
      expect(msecs).to eq(123)

      PostTiming.process_timings(user, post.topic_id, 1, [[post.post_number, 10.minutes.to_i * 1000]])
      msecs = PostTiming.where(post_number: post.post_number, user_id: user.id).pluck(:msecs)[0]
      expect(msecs).to eq(123 + PostTiming::MAX_READ_TIME_PER_BATCH)
    end

  end

  describe 'process_timings' do

    # integration tests

    it 'processes timings correctly' do
      PostActionNotifier.enable

      post = Fabricate(:post)
      (2..5).each do |i|
        Fabricate(:post, topic: post.topic, post_number: i)
      end
      user2 = Fabricate(:coding_horror, created_at: 1.day.ago)

      PostActionCreator.like(user2, post)

      expect(post.user.unread_notifications).to eq(1)

      PostTiming.process_timings(post.user, post.topic_id, 1, [[post.post_number, 100]])

      post.user.reload
      expect(post.user.unread_notifications).to eq(0)

      PostTiming.process_timings(post.user, post.topic_id, 1, [[post.post_number, 1.day]])

      user_visit = post.user.user_visits.order('id DESC').first
      expect(user_visit.posts_read).to eq(1)

      # Skip to bottom
      PostTiming.process_timings(post.user, post.topic_id, 1, [[5, 100]])
      expect(user_visit.reload.posts_read).to eq(2)

      # Scroll up
      PostTiming.process_timings(post.user, post.topic_id, 1, [[4, 100]])
      expect(user_visit.reload.posts_read).to eq(3)
      PostTiming.process_timings(post.user, post.topic_id, 1, [[2, 100], [3, 100]])
      expect(user_visit.reload.posts_read).to eq(5)
    end

    it 'does not count private message posts read' do
      pm = Fabricate(:private_message_topic, user: Fabricate(:admin))
      user1, user2 = pm.topic_allowed_users.map(&:user)

      (1..3).each do |i|
        Fabricate(:post, topic: pm, user: user1)
      end

      PostTiming.process_timings(user2, pm.id, 10, [[1, 100]])
      user_visit = user2.user_visits.last
      expect(user_visit.posts_read).to eq(0)

      PostTiming.process_timings(user2, pm.id, 10, [[2, 100], [3, 100]])
      expect(user_visit.reload.posts_read).to eq(0)
    end
  end

  describe 'recording' do
    before do
      @post = Fabricate(:post)
      @topic = @post.topic
      @coding_horror = Fabricate(:coding_horror)
      @timing_attrs = { msecs: 1234, topic_id: @post.topic_id, user_id: @coding_horror.id, post_number: @post.post_number }
    end

    it 'adds a view to the post' do
      expect {
        PostTiming.record_timing(@timing_attrs)
        @post.reload
      }.to change(@post, :reads).by(1)
    end

    describe 'multiple calls' do
      it 'correctly works' do
        PostTiming.record_timing(@timing_attrs)
        PostTiming.record_timing(@timing_attrs)
        timing = PostTiming.find_by(topic_id: @post.topic_id, user_id: @coding_horror.id, post_number: @post.post_number)

        expect(timing).to be_present
        expect(timing.msecs).to eq(2468)

        expect(@coding_horror.user_stat.posts_read_count).to eq(1)
      end

    end

  end

  describe 'decrementing posts read count when destroying post timings' do
    let(:initial_read_count) { 0 }
    let(:post) { Fabricate(:post, reads: initial_read_count) }

    before do
      PostTiming.process_timings(post.user, post.topic_id, 1, [[post.post_number, 100]])
    end

    it '#destroy_last_for decrements the reads count for a post' do
      PostTiming.destroy_last_for(post.user, post.topic_id)

      expect(post.reload.reads).to eq initial_read_count
    end

    it '#destroy_for decrements the reads count for a post' do
      PostTiming.destroy_for(post.user, [post.topic_id])

      expect(post.reload.reads).to eq initial_read_count
    end
  end
end
