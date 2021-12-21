# frozen_string_literal: true

require 'rails_helper'

describe UserStat do

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
        fab!(:topic) { Fabricate(:topic) }
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

  describe 'ensure consistency!' do
    it 'can update first unread' do
      post = create_post

      freeze_time 10.minutes.from_now
      create_post(topic_id: post.topic_id)

      post.user.update!(last_seen_at: Time.now)

      UserStat.ensure_consistency!

      post.user.user_stat.reload
      expect(post.user.user_stat.first_unread_at).to eq_time(Time.zone.now)
    end

    it 'updates first unread pm timestamp correctly' do
      freeze_time

      user = Fabricate(:user, last_seen_at: Time.zone.now)
      user_2 = Fabricate(:user, last_seen_at: Time.zone.now)
      pm_topic = Fabricate(:private_message_topic, user: user, recipient: user_2)
      create_post(user: user, topic_id: pm_topic.id)

      TopicUser.change(user.id, pm_topic.id,
        notification_level: TopicUser.notification_levels[:tracking]
      )

      # user that is not tracking PM topic
      TopicUser.change(user_2.id, pm_topic.id,
        notification_level: TopicUser.notification_levels[:regular]
      )

      # User that has not been seen recently
      user_3 = Fabricate(:user, last_seen_at: 1.year.ago)
      pm_topic.allowed_users << user_3

      TopicUser.change(user_3.id, pm_topic.id,
        notification_level: TopicUser.notification_levels[:tracking]
      )

      user_3_orig_first_unread_pm_at = user_3.user_stat.first_unread_pm_at

      # User that is not related to the PM
      user_4 = Fabricate(:user, last_seen_at: Time.zone.now)
      user_4_orig_first_unread_pm_at = user_4.user_stat.first_unread_pm_at

      # User for another PM topic
      user_5 = Fabricate(:user, last_seen_at: Time.zone.now)
      user_6 = Fabricate(:user, last_seen_at: 10.minutes.ago)
      pm_topic_2 = Fabricate(:private_message_topic, user: user_5, recipient: user_6)
      create_post(user: user_5, topic_id: pm_topic_2.id)

      TopicUser.change(user_5.id, pm_topic_2.id,
        notification_level: TopicUser.notification_levels[:tracking]
      )

      # User out of last seen limit
      TopicUser.change(user_6.id, pm_topic_2.id,
        notification_level: TopicUser.notification_levels[:tracking]
      )

      create_post(user: user_6, topic_id: pm_topic_2.id)
      user_6_orig_first_unread_pm_at = user_6.user_stat.first_unread_pm_at

      create_post(user: user_2, topic_id: pm_topic.id)
      create_post(user: user_6, topic_id: pm_topic_2.id)
      pm_topic.update!(updated_at: 10.minutes.from_now)
      pm_topic_2.update!(updated_at: 20.minutes.from_now)

      stub_const(UserStat, "UPDATE_UNREAD_USERS_LIMIT", 4) do
        UserStat.ensure_consistency!(1.hour.ago)
      end

      # User affected
      expect(user.user_stat.reload.first_unread_pm_at).to be_within(1.seconds).of(pm_topic.reload.updated_at)
      expect(user_2.user_stat.reload.first_unread_pm_at).to be_within(1.seconds).of(UserStat::UPDATE_UNREAD_MINUTES_AGO.minutes.ago)
      expect(user_3.user_stat.reload.first_unread_pm_at).to eq_time(user_3_orig_first_unread_pm_at)
      expect(user_4.user_stat.reload.first_unread_pm_at).to be_within(1.seconds).of(UserStat::UPDATE_UNREAD_MINUTES_AGO.minutes.ago)
      expect(user_5.user_stat.reload.first_unread_pm_at).to eq_time(pm_topic_2.reload.updated_at)
      expect(user_6.user_stat.reload.first_unread_pm_at).to eq_time(user_6_orig_first_unread_pm_at)
    end
  end

  describe 'update_time_read!' do
    fab!(:user) { Fabricate(:user) }
    let(:stat) { user.user_stat }

    it 'always expires redis key' do
      # this tests implementation which is not 100% ideal
      # that said, redis key leaks are not good
      stat.update_time_read!
      ttl = Discourse.redis.ttl(UserStat.last_seen_key(user.id))
      expect(ttl).to be > 0
      expect(ttl).to be <= UserStat::MAX_TIME_READ_DIFF
    end

    it 'makes no changes if nothing is cached' do
      Discourse.redis.del(UserStat.last_seen_key(user.id))
      stat.update_time_read!
      stat.reload
      expect(stat.time_read).to eq(0)
    end

    it 'makes a change if time read is below threshold' do
      freeze_time
      UserStat.cache_last_seen(user.id, (Time.now - 10).to_f)
      stat.update_time_read!
      stat.reload
      expect(stat.time_read).to eq(10)
    end

    it 'makes no change if time read is above threshold' do
      freeze_time

      t = Time.now - 1 - UserStat::MAX_TIME_READ_DIFF
      UserStat.cache_last_seen(user.id, t.to_f)

      stat.update_time_read!
      stat.reload
      expect(stat.time_read).to eq(0)
    end

  end

  describe 'update_distinct_badge_count' do
    fab!(:user) { Fabricate(:user) }
    let(:stat) { user.user_stat }
    fab!(:badge1) { Fabricate(:badge) }
    fab!(:badge2) { Fabricate(:badge) }

    it "updates counts correctly" do
      expect(stat.reload.distinct_badge_count).to eq(0)
      BadgeGranter.grant(badge1, user)
      expect(stat.reload.distinct_badge_count).to eq(1)
      BadgeGranter.grant(badge1, user)
      expect(stat.reload.distinct_badge_count).to eq(1)
      BadgeGranter.grant(badge2, user)
      expect(stat.reload.distinct_badge_count).to eq(2)
      user.reload.user_badges.destroy_all
      expect(stat.reload.distinct_badge_count).to eq(0)
    end

    it "can update counts for all users simultaneously" do
      user2 = Fabricate(:user)
      stat2 = user2.user_stat

      BadgeGranter.grant(badge1, user)
      BadgeGranter.grant(badge1, user)
      BadgeGranter.grant(badge2, user)

      BadgeGranter.grant(badge1, user2)

      # Set some clearly incorrect values
      stat.update(distinct_badge_count: 999)
      stat2.update(distinct_badge_count: 999)

      UserStat.ensure_consistency!

      expect(stat.reload.distinct_badge_count).to eq(2)
      expect(stat2.reload.distinct_badge_count).to eq(1)
    end

    it "ignores disabled badges" do
      BadgeGranter.grant(badge1, user)
      BadgeGranter.grant(badge2, user)
      expect(stat.reload.distinct_badge_count).to eq(2)

      badge2.update(enabled: false)
      expect(stat.reload.distinct_badge_count).to eq(1)

      badge2.update(enabled: true)
      expect(stat.reload.distinct_badge_count).to eq(2)
    end

  end

  describe '.update_draft_count' do
    fab!(:user) { Fabricate(:user) }

    it 'updates draft_count' do
      Draft.create!(user: user, draft_key: "topic_1", data: {})
      Draft.create!(user: user, draft_key: "new_topic", data: {})
      Draft.create!(user: user, draft_key: "topic_2", data: {})
      UserStat.update_all(draft_count: 0)

      UserStat.update_draft_count(user.id)
      expect(user.user_stat.draft_count).to eq(3)
    end
  end

  describe "#update_pending_posts" do
    subject(:update_pending_posts) { stat.update_pending_posts }

    let!(:reviewable) { Fabricate(:reviewable_queued_post) }
    let(:user) { reviewable.created_by }
    let(:stat) { user.user_stat }

    before do
      stat.update!(pending_posts_count: 0) # the reviewable callback will have set this to 1 already.
    end

    it "sets 'pending_posts_count'" do
      expect { update_pending_posts }.to change { stat.pending_posts_count }.to 1
    end

    it "publishes a message to clients" do
      MessageBus.expects(:publish).with("/u/#{user.username_lower}/counters",
                                        { pending_posts_count: 1 },
                                        user_ids: [user.id], group_ids: [Group::AUTO_GROUPS[:staff]])
      update_pending_posts
    end
  end
end
