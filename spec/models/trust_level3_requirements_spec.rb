# frozen_string_literal: true

RSpec.describe TrustLevel3Requirements do
  subject(:tl3_requirements) { described_class.new(user) }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:moderator)
  fab!(:topic1, :topic)
  fab!(:topic2, :topic)
  fab!(:topic3, :topic)
  fab!(:topic4, :topic)

  before { described_class.clear_cache }

  def make_view(topic, at, user_id)
    TopicViewItem.add(topic.id, "11.22.33.44", user_id, at, _skip_redis = true)
  end

  def like_at(created_by, post, created_at)
    PostActionCreator.new(
      created_by,
      post,
      PostActionType.types[:like],
      created_at: created_at,
    ).perform
  end

  describe "requirements" do
    describe "penalty_counts" do
      it "returns if the user has been silenced in last 6 months" do
        expect(tl3_requirements.penalty_counts.silenced).to eq(0)
        expect(tl3_requirements.penalty_counts.total).to eq(0)
        UserSilencer.new(user, moderator).silence
        expect(tl3_requirements.penalty_counts.silenced).to eq(1)
        expect(tl3_requirements.penalty_counts.total).to eq(1)
        UserSilencer.new(user, moderator).unsilence
        expect(tl3_requirements.penalty_counts.silenced).to eq(0)
        expect(tl3_requirements.penalty_counts.total).to eq(0)
      end

      it "ignores system user unsilences" do
        expect(tl3_requirements.penalty_counts.silenced).to eq(0)
        expect(tl3_requirements.penalty_counts.total).to eq(0)
        UserSilencer.new(user, moderator).silence
        expect(tl3_requirements.penalty_counts.silenced).to eq(1)
        expect(tl3_requirements.penalty_counts.total).to eq(1)
        UserSilencer.new(user, Discourse.system_user).unsilence
        expect(tl3_requirements.penalty_counts.silenced).to eq(1)
        expect(tl3_requirements.penalty_counts.total).to eq(1)
      end

      it "returns if the user has been suspended in last 6 months" do
        user.save!

        expect(tl3_requirements.penalty_counts.suspended).to eq(0)
        expect(tl3_requirements.penalty_counts.total).to eq(0)

        UserHistory.create!(
          target_user_id: user.id,
          acting_user_id: moderator.id,
          action: UserHistory.actions[:suspend_user],
        )

        expect(tl3_requirements.penalty_counts.suspended).to eq(1)
        expect(tl3_requirements.penalty_counts.total).to eq(1)

        UserHistory.create!(
          target_user_id: user.id,
          acting_user_id: moderator.id,
          action: UserHistory.actions[:unsuspend_user],
        )

        expect(tl3_requirements.penalty_counts.suspended).to eq(0)
        expect(tl3_requirements.penalty_counts.total).to eq(0)
      end

      it "ignores system user un-suspend" do
        user.save!

        expect(tl3_requirements.penalty_counts.suspended).to eq(0)
        expect(tl3_requirements.penalty_counts.total).to eq(0)

        UserHistory.create!(
          target_user_id: user.id,
          acting_user_id: Discourse.system_user.id,
          action: UserHistory.actions[:suspend_user],
        )

        expect(tl3_requirements.penalty_counts.suspended).to eq(1)
        expect(tl3_requirements.penalty_counts.total).to eq(1)

        UserHistory.create!(
          target_user_id: user.id,
          acting_user_id: Discourse.system_user.id,
          action: UserHistory.actions[:unsuspend_user],
        )

        expect(tl3_requirements.penalty_counts.suspended).to eq(1)
        expect(tl3_requirements.penalty_counts.total).to eq(1)
      end

      it "does not return if the user been silenced or suspended over 6 months ago" do
        freeze_time 1.year.ago do
          UserSilencer.new(user, moderator, silenced_till: 1.months.from_now).silence
          UserHistory.create!(target_user_id: user.id, action: UserHistory.actions[:suspend_user])
        end

        expect(tl3_requirements.penalty_counts.silenced).to eq(0)
        expect(tl3_requirements.penalty_counts.suspended).to eq(0)
        expect(tl3_requirements.penalty_counts.total).to eq(0)

        freeze_time 3.months.ago do
          UserSilencer.new(user).unsilence
          UserSilencer.new(user, moderator, silenced_till: 1.months.from_now).silence
          UserHistory.create!(target_user_id: user.id, action: UserHistory.actions[:suspend_user])
        end

        expect(tl3_requirements.penalty_counts.silenced).to eq(1)
        expect(tl3_requirements.penalty_counts.suspended).to eq(1)
        expect(tl3_requirements.penalty_counts.total).to eq(2)
      end

      it "does return if the user has been silenced or suspended over 6 months ago and continues" do
        freeze_time 1.year.ago do
          UserSilencer.new(user, moderator, silenced_till: 10.years.from_now).silence
          UserHistory.create!(target_user_id: user.id, action: UserHistory.actions[:suspend_user])
          user.update(suspended_till: 10.years.from_now)
        end

        expect(tl3_requirements.penalty_counts.silenced).to eq(1)
        expect(tl3_requirements.penalty_counts.suspended).to eq(1)
        expect(tl3_requirements.penalty_counts.total).to eq(2)
      end
    end

    it "time_period uses site setting" do
      SiteSetting.tl3_time_period = 80
      expect(tl3_requirements.time_period).to eq(80)
    end

    it "min_days_visited uses site setting" do
      SiteSetting.tl3_requires_days_visited = 66
      expect(tl3_requirements.min_days_visited).to eq(66)
    end

    it "min_topics_replied_to uses site setting" do
      SiteSetting.tl3_requires_topics_replied_to = 12
      expect(tl3_requirements.min_topics_replied_to).to eq(12)
    end

    it "min_topics_viewed depends on site setting and number of topics created" do
      SiteSetting.tl3_requires_topics_viewed = 75
      described_class.stubs(:num_topics_in_time_period).returns(31)
      expect(tl3_requirements.min_topics_viewed).to eq(23)
    end

    it "min_topics_viewed is capped" do
      SiteSetting.tl3_requires_topics_viewed = 75
      described_class.stubs(:num_topics_in_time_period).returns(31)
      SiteSetting.tl3_requires_topics_viewed_cap = 20
      expect(tl3_requirements.min_topics_viewed).to eq(20)
    end

    it "min_posts_read depends on site setting and number of posts created" do
      SiteSetting.tl3_requires_posts_read = 66
      described_class.stubs(:num_posts_in_time_period).returns(1234)
      expect(tl3_requirements.min_posts_read).to eq(814)
    end

    it "min_posts_read is capped" do
      SiteSetting.tl3_requires_posts_read = 66
      described_class.stubs(:num_posts_in_time_period).returns(1234)
      SiteSetting.tl3_requires_posts_read_cap = 600
      expect(tl3_requirements.min_posts_read).to eq(600)
    end

    it "min_topics_viewed_all_time depends on site setting" do
      SiteSetting.tl3_requires_topics_viewed_all_time = 75
      expect(tl3_requirements.min_topics_viewed_all_time).to eq(75)
    end

    it "min_posts_read_all_time depends on site setting" do
      SiteSetting.tl3_requires_posts_read_all_time = 1001
      expect(tl3_requirements.min_posts_read_all_time).to eq(1001)
    end

    it "max_flagged_posts depends on site setting" do
      SiteSetting.tl3_requires_max_flagged = 3
      expect(tl3_requirements.max_flagged_posts).to eq(3)
    end

    it "min_likes_given depends on site setting" do
      SiteSetting.tl3_requires_likes_given = 30
      expect(tl3_requirements.min_likes_given).to eq(30)
    end

    it "min_likes_received depends on site setting" do
      SiteSetting.tl3_requires_likes_received = 20
      expect(tl3_requirements.min_likes_received).to eq(20)
      expect(tl3_requirements.min_likes_received_days).to eq(7)
      expect(tl3_requirements.min_likes_received_users).to eq(5)
    end

    it "min_likes_received_days is capped" do
      SiteSetting.tl3_requires_likes_received = 600
      expect(tl3_requirements.min_likes_received).to eq(600)
      expect(tl3_requirements.min_likes_received_days).to eq(75) # 0.75 * tl3_time_period
    end

    it "min_likes_received_days works when time_period is 1" do
      SiteSetting.tl3_requires_likes_received = 20
      SiteSetting.tl3_time_period = 1
      expect(tl3_requirements.min_likes_received).to eq(20)
      expect(tl3_requirements.min_likes_received_days).to eq(1)
      expect(tl3_requirements.min_likes_received_users).to eq(5)
    end
  end

  describe "days_visited" do
    it "counts visits when posts were read no further back than 100 days (default time period) ago" do
      user.save
      user.update_posts_read!(1, at: 2.days.ago)
      user.update_posts_read!(1, at: 3.days.ago)
      user.update_posts_read!(0, at: 4.days.ago)
      user.update_posts_read!(3, at: 101.days.ago)
      expect(tl3_requirements.days_visited).to eq(2)
    end

    it "respects tl3_time_period setting" do
      SiteSetting.tl3_time_period = 200
      user.save
      user.update_posts_read!(1, at: 2.days.ago)
      user.update_posts_read!(1, at: 3.days.ago)
      user.update_posts_read!(0, at: 4.days.ago)
      user.update_posts_read!(3, at: 101.days.ago)
      user.update_posts_read!(4, at: 201.days.ago)
      expect(tl3_requirements.days_visited).to eq(3)
    end
  end

  describe "num_topics_replied_to" do
    it "counts topics in which user replied in last 100 days" do
      user.save

      _not_a_reply = create_post(user: user) # user created the topic, so it doesn't count

      topic1 = create_post.topic
      _reply1 = create_post(topic: topic1, user: user)
      _reply_again = create_post(topic: topic1, user: user) # two replies in one topic

      topic2 = create_post(created_at: 101.days.ago).topic
      _reply2 = create_post(topic: topic2, user: user, created_at: 101.days.ago) # topic is over 100 days old

      expect(tl3_requirements.num_topics_replied_to).to eq(1)
    end

    it "excludes private messages" do
      user.save!

      private_topic =
        create_post(
          user: moderator,
          archetype: Archetype.private_message,
          target_usernames: [user.username, moderator.username],
        ).topic

      _reply1 = create_post(topic: private_topic, user: user)

      expect(tl3_requirements.num_topics_replied_to).to eq(0)
    end
  end

  describe "topics_viewed" do
    it "counts topics views within last 100 days (default time period), not counting a topic more than once" do
      user.save
      make_view(topic1, 1.day.ago, user.id)
      make_view(topic1, 3.days.ago, user.id) # same topic, different day
      make_view(topic2, 4.days.ago, user.id)
      make_view(topic3, 101.days.ago, user.id) # too long ago
      expect(tl3_requirements.topics_viewed).to eq(2)
    end

    it "counts topics views within last 200 days, respecting tl3_time_period setting" do
      SiteSetting.tl3_time_period = 200
      user.save
      make_view(topic1, 1.day.ago, user.id)
      make_view(topic1, 3.days.ago, user.id) # same topic, different day
      make_view(topic2, 4.days.ago, user.id)
      make_view(topic3, 101.days.ago, user.id)
      make_view(topic4, 201.days.ago, user.id) # too long ago
      expect(tl3_requirements.topics_viewed).to eq(3)
    end

    it "excludes private messages" do
      user.save
      private_topic =
        create_post(
          user: moderator,
          archetype: Archetype.private_message,
          target_usernames: [user.username, moderator.username],
        ).topic

      make_view(topic1, 1.day.ago, user.id)
      make_view(private_topic, 1.day.ago, user.id)
      expect(tl3_requirements.topics_viewed).to eq(1)
    end
  end

  describe "posts_read" do
    it "counts posts read within the last 100 days" do
      user.save
      user.update_posts_read!(3, at: 2.days.ago)
      user.update_posts_read!(1, at: 3.days.ago)
      user.update_posts_read!(0, at: 4.days.ago)
      user.update_posts_read!(5, at: 101.days.ago)
      expect(tl3_requirements.posts_read).to eq(4)
    end
  end

  describe "topics_viewed_all_time" do
    it "counts topics viewed at any time" do
      user.save
      make_view(topic1, 1.day.ago, user.id)
      make_view(topic2, 100.days.ago, user.id)
      make_view(topic3, 101.days.ago, user.id)
      expect(tl3_requirements.topics_viewed_all_time).to eq(3)
    end

    it "excludes private messages" do
      user.save
      private_topic =
        create_post(
          user: moderator,
          archetype: Archetype.private_message,
          target_usernames: [user.username, moderator.username],
        ).topic

      make_view(topic1, 1.day.ago, user.id)
      make_view(topic2, 100.days.ago, user.id)
      make_view(topic3, 101.days.ago, user.id)
      make_view(private_topic, 1.day.ago, user.id)
      make_view(private_topic, 100.days.ago, user.id)
      expect(tl3_requirements.topics_viewed_all_time).to eq(3)
    end
  end

  describe "posts_read_all_time" do
    it "counts posts read at any time" do
      user.save
      user.update_posts_read!(3, at: 2.days.ago)
      user.update_posts_read!(1, at: 101.days.ago)
      expect(tl3_requirements.posts_read_all_time).to eq(4)
    end
  end

  context "with flagged posts" do
    before do
      user.save
      flags =
        %i[off_topic inappropriate notify_user notify_moderators spam].map do |t|
          Fabricate(
            :flag_post_action,
            post: Fabricate(:post, user: user),
            post_action_type_id: PostActionType.types[t],
            agreed_at: 1.minute.ago,
          )
        end

      _deferred_flags =
        %i[off_topic inappropriate notify_user notify_moderators spam].map do |t|
          Fabricate(
            :flag_post_action,
            post: Fabricate(:post, user: user),
            post_action_type_id: PostActionType.types[t],
            deferred_at: 1.minute.ago,
          )
        end

      _deleted_flags =
        %i[off_topic inappropriate notify_user notify_moderators spam].map do |t|
          Fabricate(
            :flag_post_action,
            post: Fabricate(:post, user: user),
            post_action_type_id: PostActionType.types[t],
            deleted_at: 1.minute.ago,
          )
        end

      # Same post, different user:
      Fabricate(
        :flag_post_action,
        post: flags[1].post,
        post_action_type_id: PostActionType.types[:spam],
        agreed_at: 1.minute.ago,
      )

      # Flagged their own post:
      Fabricate(
        :flag_post_action,
        user: user,
        post: Fabricate(:post, user: user),
        post_action_type_id: PostActionType.types[:spam],
        agreed_at: 1.minute.ago,
      )

      # More than 100 days ago:
      Fabricate(
        :flag_post_action,
        post: Fabricate(:post, user: user, created_at: 101.days.ago),
        post_action_type_id: PostActionType.types[:spam],
        created_at: 101.days.ago,
        agreed_at: 1.day.ago,
      )
    end

    it "num_flagged_posts and num_flagged_by_users count spam and inappropriate agreed flags in the last 100 days" do
      expect(tl3_requirements.num_flagged_posts).to eq(2)
      expect(tl3_requirements.num_flagged_by_users).to eq(3)
    end
  end

  describe "num_likes_given" do
    before do
      UserActionManager.enable
      user.save
    end

    let(:recent_post1) { create_post(created_at: 1.hour.ago) }
    let(:recent_post2) { create_post(created_at: 10.days.ago) }
    let(:old_post) { create_post(created_at: 102.days.ago) }
    let(:private_post) do
      create_post(
        user: moderator,
        archetype: Archetype.private_message,
        target_usernames: [user.username, moderator.username],
      )
    end

    it "counts likes given in the last 100 days" do
      like_at(user, recent_post1, 2.hours.ago)
      like_at(user, recent_post2, 5.days.ago)
      like_at(user, old_post, 101.days.ago)

      expect(tl3_requirements.num_likes_given).to eq(2)
    end

    it "excludes private messages" do
      like_at(user, recent_post1, 2.hours.ago)
      like_at(user, private_post, 2.hours.ago)

      expect(tl3_requirements.num_likes_given).to eq(1)
    end
  end

  describe "num_likes_received" do
    before { UserActionManager.enable }

    let(:topic) { Fabricate(:topic, user: user, created_at: 102.days.ago) }
    let(:old_post) { create_post(topic: topic, user: user, created_at: 102.days.ago) }
    let(:recent_post1) { create_post(topic: topic, user: user, created_at: 1.hour.ago) }
    let(:recent_post2) { create_post(topic: topic, user: user, created_at: 10.days.ago) }
    let(:private_post) do
      create_post(
        user: user,
        archetype: Archetype.private_message,
        target_usernames: [liker.username, liker2.username],
      )
    end

    let(:liker) { Fabricate(:user) }
    let(:liker2) { Fabricate(:user) }

    it "counts likes received in the last 100 days" do
      like_at(liker, recent_post1, 2.hours.ago)
      like_at(liker2, recent_post1, 2.hours.ago)
      like_at(liker, recent_post2, 5.days.ago)
      like_at(liker, old_post, 101.days.ago)
      like_at(liker, private_post, 2.hours.ago)
      like_at(liker2, private_post, 5.days.ago)

      expect(tl3_requirements.num_likes_received).to eq(3)
      expect(tl3_requirements.num_likes_received_days).to eq(2)
      expect(tl3_requirements.num_likes_received_users).to eq(2)
    end
  end

  describe "requirements with defaults" do
    before do
      tl3_requirements.stubs(:min_days_visited).returns(50)
      tl3_requirements.stubs(:min_topics_replied_to).returns(10)
      tl3_requirements.stubs(:min_topics_viewed).returns(25)
      tl3_requirements.stubs(:min_posts_read).returns(25)
      tl3_requirements.stubs(:min_topics_viewed_all_time).returns(200)
      tl3_requirements.stubs(:min_posts_read_all_time).returns(500)
      tl3_requirements.stubs(:max_flagged_posts).returns(5)
      tl3_requirements.stubs(:max_flagged_by_users).returns(5)
      tl3_requirements.stubs(:min_likes_given).returns(30)
      tl3_requirements.stubs(:min_likes_received).returns(20)
      tl3_requirements.stubs(:min_likes_received_days).returns(7)
      tl3_requirements.stubs(:min_likes_received_users).returns(5)

      tl3_requirements.stubs(:days_visited).returns(50)
      tl3_requirements.stubs(:num_topics_replied_to).returns(10)
      tl3_requirements.stubs(:topics_viewed).returns(25)
      tl3_requirements.stubs(:posts_read).returns(25)
      tl3_requirements.stubs(:topics_viewed_all_time).returns(200)
      tl3_requirements.stubs(:posts_read_all_time).returns(500)
      tl3_requirements.stubs(:num_flagged_posts).returns(0)
      tl3_requirements.stubs(:num_flagged_by_users).returns(0)
      tl3_requirements.stubs(:num_likes_given).returns(30)
      tl3_requirements.stubs(:num_likes_received).returns(20)
      tl3_requirements.stubs(:num_likes_received_days).returns(7)
      tl3_requirements.stubs(:num_likes_received_users).returns(5)
    end

    it "are met when all requirements are met" do
      expect(tl3_requirements.requirements_met?).to eq(true)
    end

    it "are not met if too few days visited" do
      tl3_requirements.stubs(:days_visited).returns(49)
      expect(tl3_requirements.requirements_met?).to eq(false)
    end

    it "are not lost if requirements are close" do
      tl3_requirements.stubs(:days_visited).returns(45)
      tl3_requirements.stubs(:num_topics_replied_to).returns(9)
      tl3_requirements.stubs(:topics_viewed).returns(23)
      tl3_requirements.stubs(:posts_read).returns(23)
      tl3_requirements.stubs(:num_likes_given).returns(29)
      tl3_requirements.stubs(:num_likes_received).returns(19)
      expect(tl3_requirements.requirements_lost?).to eq(false)
    end

    it "are lost if not enough visited" do
      tl3_requirements.stubs(:days_visited).returns(44)
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    it "are lost if not enough topics replied to" do
      tl3_requirements.stubs(:num_topics_replied_to).returns(8)
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    it "are lost if not enough topics viewed" do
      tl3_requirements.stubs(:topics_viewed).returns(22)
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    it "are lost if not enough posts read" do
      tl3_requirements.stubs(:posts_read).returns(22)
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    it "are not met if not enough likes given" do
      tl3_requirements.stubs(:num_likes_given).returns(29)
      expect(tl3_requirements.requirements_met?).to eq(false)
    end

    it "are not met if not enough likes received" do
      tl3_requirements.stubs(:num_likes_received).returns(19)
      expect(tl3_requirements.requirements_met?).to eq(false)
    end

    it "are not met if not enough likes received on different days" do
      tl3_requirements.stubs(:num_likes_received_days).returns(6)
      expect(tl3_requirements.requirements_met?).to eq(false)
    end

    it "are not met if not enough likes received by different users" do
      tl3_requirements.stubs(:num_likes_received_users).returns(4)
      expect(tl3_requirements.requirements_met?).to eq(false)
    end

    it "are lost if not enough likes given" do
      tl3_requirements.stubs(:num_likes_given).returns(26)
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    it "are lost if not enough likes received" do
      tl3_requirements.stubs(:num_likes_received).returns(17)
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    it "are not met if suspended" do
      user.suspended_till = 3.weeks.from_now
      expect(tl3_requirements.requirements_met?).to eq(false)
    end

    it "are not met if silenced" do
      user.silenced_till = 3.weeks.from_now
      expect(tl3_requirements.requirements_met?).to eq(false)
    end

    it "are not met if previously silenced" do
      user.save
      UserHistory.create(target_user_id: user.id, action: UserHistory.actions[:silence_user])
      expect(tl3_requirements.requirements_met?).to eq(false)
    end

    it "are not met if previously suspended" do
      user.save
      UserHistory.create(target_user_id: user.id, action: UserHistory.actions[:suspend_user])
      expect(tl3_requirements.requirements_met?).to eq(false)
    end

    it "are lost if not enough likes received on different days" do
      tl3_requirements.stubs(:num_likes_received_days).returns(4)
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    it "are lost if not enough likes received by different users" do
      tl3_requirements.stubs(:num_likes_received_users).returns(3)
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    it "are lost if suspended" do
      user.suspended_till = 4.weeks.from_now
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    it "are lost if silenced" do
      user.silenced_till = 4.weeks.from_now
      expect(tl3_requirements.requirements_lost?).to eq(true)
    end

    [3, 4].each do |default_tl|
      it "is not lost if default_trust_level is #{default_tl}" do
        SiteSetting.default_trust_level = default_tl
        tl3_requirements.stubs(:days_visited).returns(1)
        expect(tl3_requirements.requirements_lost?).to eq(false)
      end
    end
  end
end
