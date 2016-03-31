require 'rails_helper'

describe UserStat do

  it { is_expected.to belong_to :user }

  it "is created automatically when a user is created" do
    user = Fabricate(:evil_trout)
    expect(user.user_stat).to be_present

    # It populates the `new_since` field by default
    expect(user.user_stat.new_since).to be_present
  end

  context '#update_view_counts' do

    let(:user) { Fabricate(:user) }
    let(:stat) { user.user_stat }

    context 'topics_entered' do
      context 'without any views' do
        it "doesn't increase the user's topics_entered" do
          expect { UserStat.update_view_counts; stat.reload }.not_to change(stat, :topics_entered)
        end
      end

      context 'with a view' do
        let(:topic) { Fabricate(:topic) }
        let!(:view) { TopicViewItem.add(topic.id, '127.0.0.1', user.id) }

        before do
          user.update_column :last_seen_at, 1.second.ago
        end

        it "adds one to the topics entered" do
          UserStat.update_view_counts
          stat.reload
          expect(stat.topics_entered).to eq(1)
        end

        it "won't record a second view as a different topic" do
          TopicViewItem.add(topic.id, '127.0.0.1', user.id)
          UserStat.update_view_counts
          stat.reload
          expect(stat.topics_entered).to eq(1)
        end

      end
    end

    context 'posts_read_count' do
      context 'without any post timings' do
        it "doesn't increase the user's posts_read_count" do
          expect { UserStat.update_view_counts; stat.reload }.not_to change(stat, :posts_read_count)
        end
      end

      context 'with a post timing' do
        let!(:post) { Fabricate(:post) }
        let!(:post_timings) do
          PostTiming.record_timing(msecs: 1234, topic_id: post.topic_id, user_id: user.id, post_number: post.post_number)
        end

        before do
          user.update_column :last_seen_at, 1.second.ago
        end

        it "increases posts_read_count" do
          UserStat.update_view_counts
          stat.reload
          expect(stat.posts_read_count).to eq(1)
        end
      end
    end
  end


  describe 'update_time_read!' do
    let(:user) { Fabricate(:user) }
    let(:stat) { user.user_stat }

    it 'makes no changes if nothing is cached' do
      stat.expects(:last_seen_cached).returns(nil)
      stat.update_time_read!
      stat.reload
      expect(stat.time_read).to eq(0)
    end

    it 'makes a change if time read is below threshold' do
      stat.expects(:last_seen_cached).returns(Time.now - 10)
      stat.update_time_read!
      stat.reload
      expect(stat.time_read).to eq(10)
    end

    it 'makes no change if time read is above threshold' do
      t = Time.now - 1 - UserStat::MAX_TIME_READ_DIFF
      stat.expects(:last_seen_cached).returns(t)
      stat.update_time_read!
      stat.reload
      expect(stat.time_read).to eq(0)
    end

  end
end
