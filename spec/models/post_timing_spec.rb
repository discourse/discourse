require 'spec_helper'

describe PostTiming do

  it { should belong_to :topic }
  it { should belong_to :user }

  it { should validate_presence_of :post_number }
  it { should validate_presence_of :msecs }

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

    def topic_user(user_id, last_read_post_number, seen_post_count)
      TopicUser.create!(
                        topic_id: topic_id,
                        user_id: user_id,
                        last_read_post_number: last_read_post_number,
                        seen_post_count: seen_post_count
                       )
    end

    it 'works correctly' do
      timing(1,1)
      timing(2,1)
      timing(2,2)
      timing(3,1)
      timing(3,2)
      timing(3,3)

      tu_one = topic_user(1,1,1)
      tu_two = topic_user(2,2,2)
      tu_three = topic_user(3,3,3)

      PostTiming.pretend_read(topic_id, 2, 3)

      PostTiming.where(topic_id: topic_id, user_id: 1, post_number: 3).count.should == 0
      PostTiming.where(topic_id: topic_id, user_id: 2, post_number: 3).count.should == 1
      PostTiming.where(topic_id: topic_id, user_id: 3, post_number: 3).count.should == 1

      tu = TopicUser.where(topic_id: topic_id, user_id: 1).first
      tu.last_read_post_number.should == 1
      tu.seen_post_count.should == 1

      tu = TopicUser.where(topic_id: topic_id, user_id: 2).first
      tu.last_read_post_number.should == 3
      tu.seen_post_count.should == 3

      tu = TopicUser.where(topic_id: topic_id, user_id: 3).first
      tu.last_read_post_number.should == 3
      tu.seen_post_count.should == 3

    end
  end

  describe 'process_timings' do

    # integration test

    it 'processes timings correctly' do

      ActiveRecord::Base.observers.enable :all

      post = Fabricate(:post)
      user2 = Fabricate(:coding_horror)

      PostAction.act(user2, post, PostActionType.types[:like])

      post.user.unread_notifications.should == 1
      post.user.unread_notifications_by_type.should == { Notification.types[:liked] => 1 }

      PostTiming.process_timings(post.user, post.topic_id, 1, [[post.post_number, 100]])

      post.user.reload
      post.user.unread_notifications_by_type.should == {}
      post.user.unread_notifications.should == 0

    end
  end

  describe 'recording' do
    before do
      @post = Fabricate(:post)
      @topic = @post.topic
      @coding_horror = Fabricate(:coding_horror)
      @timing_attrs = {msecs: 1234, topic_id: @post.topic_id, user_id: @coding_horror.id, post_number: @post.post_number}
    end

    it 'creates a post timing record' do
      lambda {
        PostTiming.record_timing(@timing_attrs)
      }.should change(PostTiming, :count).by(1)
    end

    it 'adds a view to the post' do
      lambda {
        PostTiming.record_timing(@timing_attrs)
        @post.reload
      }.should change(@post, :reads).by(1)
    end

    describe 'multiple calls' do
      before do
        PostTiming.record_timing(@timing_attrs)
        PostTiming.record_timing(@timing_attrs)
        @timing = PostTiming.where(topic_id: @post.topic_id, user_id: @coding_horror.id, post_number: @post.post_number).first
      end

      it 'creates a timing record' do
        @timing.should be_present
      end

      it 'sums the msecs together' do
        @timing.msecs.should == 2468
      end
    end

    describe 'avg times' do

      describe 'posts' do
        it 'has no avg_time by default' do
          @post.avg_time.should be_blank
        end

        it "doesn't change when we calculate the avg time for the post because there's no timings" do
          Post.calculate_avg_time
          @post.reload
          @post.avg_time.should be_blank
        end
      end

      describe 'topics' do
        it 'has no avg_time by default' do
          @topic.avg_time.should be_blank
        end

        it "doesn't change when we calculate the avg time for the post because there's no timings" do
          Topic.calculate_avg_time
          @topic.reload
          @topic.avg_time.should be_blank
        end
      end

      describe "it doesn't create an avg time for the same user" do
        it 'something' do
          PostTiming.record_timing(@timing_attrs.merge(user_id: @post.user_id))
          Post.calculate_avg_time
          @post.reload
          @post.avg_time.should be_blank
        end

      end

      describe 'with a timing for another user' do
        before do
          PostTiming.record_timing(@timing_attrs)
          Post.calculate_avg_time
          @post.reload
        end

        it 'has a post avg_time from the timing' do
          @post.avg_time.should be_present
        end

        describe 'forum topics' do
          before do
            Topic.calculate_avg_time
            @topic.reload
          end

          it 'has an avg_time from the timing' do
            @topic.avg_time.should be_present
          end

        end

      end

    end

  end

end
