require 'spec_helper'

describe PostTiming do

  it { should belong_to :topic }
  it { should belong_to :user }

  it { should validate_presence_of :post_number }
  it { should validate_presence_of :msecs }

  describe 'process_timings' do

    # integration test

    it 'processes timings correctly' do
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
