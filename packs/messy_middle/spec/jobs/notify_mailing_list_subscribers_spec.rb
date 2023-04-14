# frozen_string_literal: true

RSpec.describe Jobs::NotifyMailingListSubscribers do
  fab!(:mailing_list_user) { Fabricate(:user) }

  before do
    mailing_list_user.user_option.update(mailing_list_mode: true, mailing_list_mode_frequency: 1)
  end
  before { SiteSetting.tagging_enabled = true }

  fab!(:tag) { Fabricate(:tag) }
  fab!(:topic) { Fabricate(:topic, tags: [tag]) }
  fab!(:user) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post, topic: topic, user: user) }

  shared_examples "no emails" do
    it "doesn't send any emails" do
      UserNotifications.expects(:mailing_list_notify).with(mailing_list_user, post).never
      Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
    end
  end

  shared_examples "one email" do
    it "sends the email" do
      UserNotifications.expects(:mailing_list_notify).with(mailing_list_user, post).once
      Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
    end

    it "triggers :notify_mailing_list_subscribers" do
      events =
        DiscourseEvent.track_events do
          Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
        end
      expect(events).to include(
        event_name: :notify_mailing_list_subscribers,
        params: [[mailing_list_user], post],
      )
    end
  end

  context "when mailing list mode is globally disabled" do
    before { SiteSetting.disable_mailing_list_mode = true }
    include_examples "no emails"
  end

  context "when mailing list mode is globally enabled" do
    before { SiteSetting.disable_mailing_list_mode = false }

    context "when site requires approval and user is not approved" do
      before do
        SiteSetting.login_required = true
        SiteSetting.must_approve_users = true

        User.update_all(approved: false)
      end
      include_examples "no emails"
    end

    context "with an invalid post_id" do
      before { post.update(deleted_at: Time.now) }
      include_examples "no emails"
    end

    context "with a deleted post" do
      before { post.update(deleted_at: Time.now) }
      include_examples "no emails"
    end

    context "with a empty post" do
      before { post.update_columns(raw: "") }
      include_examples "no emails"
    end

    context "with a user_deleted post" do
      before { post.update(user_deleted: true) }
      include_examples "no emails"
    end

    context "with a deleted topic" do
      before { post.topic.update(deleted_at: Time.now) }
      include_examples "no emails"
    end

    context "with a private message" do
      before do
        post.topic.update!(archetype: Archetype.private_message, category: nil)
        TopicAllowedUser.create(topic: post.topic, user: mailing_list_user)
        post.topic.reload
      end
      include_examples "no emails"
    end

    context "with a valid post from another user" do
      context "when to an inactive user" do
        before { mailing_list_user.update(active: false) }
        include_examples "no emails"
      end

      context "when to a silenced user" do
        before { mailing_list_user.update(silenced_till: 1.year.from_now) }
        include_examples "no emails"
      end

      context "when to a suspended user" do
        before { mailing_list_user.update(suspended_till: 1.day.from_now) }
        include_examples "no emails"
      end

      context "when to an anonymous user" do
        fab!(:mailing_list_user) { Fabricate(:anonymous) }
        include_examples "no emails"
      end

      context "when to an user who has disabled mailing list mode" do
        before { mailing_list_user.user_option.update(mailing_list_mode: false) }
        include_examples "no emails"
      end

      context "when to an user who has frequency set to 'always'" do
        before { mailing_list_user.user_option.update(mailing_list_mode_frequency: 1) }
        include_examples "one email"
      end

      context "when to an user who has frequency set to 'no echo'" do
        before { mailing_list_user.user_option.update(mailing_list_mode_frequency: 2) }
        include_examples "one email"
      end

      context "when from a muted user" do
        before { MutedUser.create(user: mailing_list_user, muted_user: user) }
        include_examples "no emails"
      end

      context "when from an ignored user" do
        before { Fabricate(:ignored_user, user: mailing_list_user, ignored_user: user) }
        include_examples "no emails"
      end

      context "when from a muted topic" do
        before do
          TopicUser.create(
            user: mailing_list_user,
            topic: post.topic,
            notification_level: TopicUser.notification_levels[:muted],
          )
        end
        include_examples "no emails"
      end

      context "when from a muted category" do
        before do
          CategoryUser.create(
            user: mailing_list_user,
            category: post.topic.category,
            notification_level: CategoryUser.notification_levels[:muted],
          )
        end
        include_examples "no emails"
      end

      context "with mute all categories by default setting" do
        before { SiteSetting.mute_all_categories_by_default = true }
        include_examples "no emails"
      end

      context "with mute all categories by default setting but user is watching category" do
        before do
          SiteSetting.mute_all_categories_by_default = true
          CategoryUser.create(
            user: mailing_list_user,
            category: post.topic.category,
            notification_level: CategoryUser.notification_levels[:watching],
          )
        end
        include_examples "one email"
      end

      context "with mute all categories by default setting but user is watching tag" do
        before do
          SiteSetting.mute_all_categories_by_default = true
          TagUser.create(
            user: mailing_list_user,
            tag: tag,
            notification_level: TagUser.notification_levels[:watching],
          )
        end
        include_examples "one email"
      end

      context "with mute all categories by default setting but user is watching topic" do
        before do
          SiteSetting.mute_all_categories_by_default = true
          TopicUser.create(
            user: mailing_list_user,
            topic: post.topic,
            notification_level: TopicUser.notification_levels[:watching],
          )
        end
        include_examples "one email"
      end

      context "when from a muted tag" do
        before do
          TagUser.create(
            user: mailing_list_user,
            tag: tag,
            notification_level: TagUser.notification_levels[:muted],
          )
        end
        include_examples "no emails"
      end

      context "when max emails per day was reached" do
        before { SiteSetting.max_emails_per_day_per_user = 2 }

        it "doesn't send any emails" do
          (SiteSetting.max_emails_per_day_per_user + 1).times do
            mailing_list_user.email_logs.create(
              email_type: "foobar",
              to_address: mailing_list_user.email,
            )
          end

          expect do
            UserNotifications.expects(:mailing_list_notify).with(mailing_list_user, post).never

            2.times { Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id) }

            Jobs::NotifyMailingListSubscribers.new.execute(post_id: Fabricate(:post, user: user).id)
          end.to change { SkippedEmailLog.count }.by(1)

          expect(
            SkippedEmailLog.exists?(
              email_type: "mailing_list",
              user: mailing_list_user,
              post: post,
              to_address: mailing_list_user.email,
              reason_type: SkippedEmailLog.reason_types[:exceeded_emails_limit],
            ),
          ).to eq(true)

          freeze_time(Time.zone.now.tomorrow + 1.second)

          expect do
            post = Fabricate(:post, user: user)

            UserNotifications.expects(:mailing_list_notify).with(mailing_list_user, post).once

            Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
          end.not_to change { SkippedEmailLog.count }
        end
      end

      context "when bounce score was reached" do
        it "doesn't send any emails" do
          mailing_list_user.user_stat.update(bounce_score: SiteSetting.bounce_score_threshold + 1)

          Jobs::NotifyMailingListSubscribers.new.execute(post_id: post.id)
          UserNotifications.expects(:mailing_list_notify).with(mailing_list_user, post).never

          expect(
            SkippedEmailLog.exists?(
              email_type: "mailing_list",
              user: mailing_list_user,
              post: post,
              to_address: mailing_list_user.email,
              reason_type: SkippedEmailLog.reason_types[:exceeded_bounces_limit],
            ),
          ).to eq(true)
        end
      end
    end

    context "with a valid post from same user" do
      fab!(:post) { Fabricate(:post, user: mailing_list_user) }

      context "when to an user who has frequency set to 'daily'" do
        before { mailing_list_user.user_option.update(mailing_list_mode_frequency: 0) }
        include_examples "no emails"
      end

      context "when to an user who has frequency set to 'always'" do
        before { mailing_list_user.user_option.update(mailing_list_mode_frequency: 1) }
        include_examples "one email"
      end

      context "when to an user who has frequency set to 'no echo'" do
        before { mailing_list_user.user_option.update(mailing_list_mode_frequency: 2) }
        include_examples "no emails"
      end
    end
  end
end
