require 'rails_helper'

describe PostTiming do

  it { is_expected.to validate_presence_of :post_number }
  it { is_expected.to validate_presence_of :msecs }

  describe 'pretend_read' do
    let!(:p1) { Fabricate(:post) }
    let!(:p2) { Fabricate(:post, topic: p1.topic, user: p1.user) }
    let!(:p3) { Fabricate(:post, topic: p1.topic, user: p1.user) }

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
      timing(1,1)
      timing(2,1)
      timing(2,2)
      timing(3,1)
      timing(3,2)
      timing(3,3)

      _tu_one = topic_user(1,1,1)
      _tu_two = topic_user(2,2,2)
      _tu_three = topic_user(3,3,3)

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

    # integration test

    it 'processes timings correctly' do

      ActiveRecord::Base.observers.enable :all

      post = Fabricate(:post)
      user2 = Fabricate(:coding_horror, created_at: 1.day.ago)

      PostAction.act(user2, post, PostActionType.types[:like])

      expect(post.user.unread_notifications).to eq(1)

      PostTiming.process_timings(post.user, post.topic_id, 1, [[post.post_number, 100]])

      post.user.reload
      expect(post.user.unread_notifications).to eq(0)

      PostTiming.process_timings(post.user, post.topic_id, 1, [[post.post_number, 1.day]])

    end
  end

  describe 'recording' do
    before do
      @post = Fabricate(:post)
      @topic = @post.topic
      @coding_horror = Fabricate(:coding_horror)
      @timing_attrs = {msecs: 1234, topic_id: @post.topic_id, user_id: @coding_horror.id, post_number: @post.post_number}
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

    describe 'avg times' do

      describe 'posts' do
        it 'has no avg_time by default' do
          expect(@post.avg_time).to be_blank
        end

        it "doesn't change when we calculate the avg time for the post because there's no timings" do
          Post.calculate_avg_time
          @post.reload
          expect(@post.avg_time).to be_blank
        end
      end

      describe 'topics' do
        it 'has no avg_time by default' do
          expect(@topic.avg_time).to be_blank
        end

        it "doesn't change when we calculate the avg time for the post because there's no timings" do
          Topic.calculate_avg_time
          @topic.reload
          expect(@topic.avg_time).to be_blank
        end
      end

      describe "it doesn't create an avg time for the same user" do
        it 'something' do
          PostTiming.record_timing(@timing_attrs.merge(user_id: @post.user_id))
          Post.calculate_avg_time
          @post.reload
          expect(@post.avg_time).to be_blank
        end

      end

      describe 'with a timing for another user' do
        before do
          PostTiming.record_timing(@timing_attrs)
          Post.calculate_avg_time
          @post.reload
        end

        it 'has a post avg_time from the timing' do
          expect(@post.avg_time).to be_present
        end

        describe 'forum topics' do
          before do
            Topic.calculate_avg_time
            @topic.reload
          end

          it 'has an avg_time from the timing' do
            expect(@topic.avg_time).to be_present
          end

        end

      end

    end

  end

end
