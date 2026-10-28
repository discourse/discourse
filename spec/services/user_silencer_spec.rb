# frozen_string_literal: true

RSpec.describe UserSilencer do
  fab!(:user) { Fabricate(:user, trust_level: 0) }
  fab!(:post) { Fabricate(:post, user: user) }
  fab!(:admin)
  fab!(:shadow) do
    Fabricate(:anonymous).tap { it.anonymous_user_master.update!(master_user: user) }
  end

  describe "silence" do
    subject(:silence_user) { silencer.silence }

    let(:silencer) { UserSilencer.new(user) }

    it "silences the user correctly" do
      expect { UserSilencer.silence(user, admin) }.to change { user.reload.silenced? }

      # no need to silence as we are already silenced
      expect { UserSilencer.silence(user) }.not_to change { Post.count }

      # post should be hidden
      post.reload
      expect(post.topic.visible).to eq(false)
      expect(post.hidden).to eq(true)

      # history should be right
      count =
        UserHistory.where(
          action: UserHistory.actions[:silence_user],
          acting_user_id: admin.id,
          target_user_id: user.id,
        ).count

      expect(count).to eq(1)
    end

    it "preserves the scheduled expiry in the log after an early unsilencing" do
      freeze_time(Time.zone.now.round)
      UserSilencer.silence(user, admin, silenced_till: 2.days.from_now)

      history = user.user_histories.find_by!(action: UserHistory.actions[:silence_user])
      expect(history.expires_at).to eq_time(user.reload.silenced_till)

      UserSilencer.unsilence(user, admin)

      expect(history.reload.expires_at).to eq_time(2.days.from_now)
      expect(
        user.user_histories.find_by!(action: UserHistory.actions[:unsilence_user]).expires_at,
      ).to be_nil
    end

    it "logs the expiry used for an indefinite silence" do
      UserSilencer.silence(user, admin)

      history = user.user_histories.find_by!(action: UserHistory.actions[:silence_user])
      expect(history.expires_at).to eq_time(user.reload.silenced_till)
    end

    it "removes featured rows for hidden topics" do
      CategoryFeaturedTopic.create!(category: post.topic.category, topic: post.topic)

      expect { UserSilencer.silence(user, admin) }.to change {
        CategoryFeaturedTopic.exists?(topic_id: post.topic_id)
      }.from(true).to(false)
    end

    it "skips sending the email for the silence PM via post alert" do
      NotificationEmailer.enable
      Jobs.run_immediately!
      UserSilencer.silence(user, admin)
      expect(ActionMailer::Base.deliveries.size).to eq(0)
    end

    it "does not hide posts for tl1" do
      user.update!(trust_level: 1)

      UserSilencer.silence(user, admin)

      post.reload
      expect(post.topic.visible).to eq(true)
      expect(post.hidden).to eq(false)
    end

    it "does not silence or hide posts for staff users" do
      user.update!(moderator: true)

      expect(UserSilencer.silence(user, admin)).to eq(false)
      expect(user.reload.silenced?).to eq(false)
      expect(post.reload.hidden).to eq(false)
      expect(post.topic.reload.visible).to eq(true)
    end

    it "allows us to silence the user for a particular post" do
      expect(UserSilencer.was_silenced_for?(post)).to eq(false)
      UserSilencer.new(user, Discourse.system_user, post_id: post.id).silence
      expect(user).to be_silenced
      expect(UserSilencer.was_silenced_for?(post)).to eq(true)
    end

    it "only hides posts from the past 24 hours" do
      old_post = Fabricate(:post, user: user, created_at: 2.days.ago)

      UserSilencer.new(user, Discourse.system_user, post_id: post.id).silence

      expect(post.reload).to be_hidden
      expect(post.topic.reload).to_not be_visible
      old_post.reload
      expect(old_post).to_not be_hidden
      expect(old_post.topic).to be_visible
    end

    it "reports each topic it unlists as unlisted by the silencing user", :aggregate_failures do
      admin = Fabricate(:admin)
      already_unlisted = Fabricate(:post, user:)
      already_unlisted.topic.update_columns(visible: false)

      events =
        DiscourseEvent.track_events(:topic_status_updated) do
          UserSilencer.new(user, admin, post_id: post.id).silence
        end

      expect(events.map { it[:params] }).to eq(
        [[post.topic, "visible", false, { acting_user: admin }]],
      )
    end

    it "reports each post it newly hides as hidden by the silencing user" do
      already_hidden = Fabricate(:post, user: user)
      already_hidden.hide!(PostActionType.types[:spam])

      events = DiscourseEvent.track_events(:post_hidden) { UserSilencer.silence(user, admin) }

      expect(events.map { |event| event[:params] }).to eq(
        [[post, { acting_user: admin, post_action_type_id: nil }]],
      )
      expect(events.first[:params].first).to have_attributes(
        hidden: true,
        hidden_reason_id: Post.hidden_reasons[:new_user_spam_threshold_reached],
      )
    end

    it "reports the system user as the actor when silencing without a user" do
      events = DiscourseEvent.track_events(:post_hidden) { UserSilencer.silence(user) }

      expect(events.map { |event| event[:params].last[:acting_user] }).to eq(
        [Discourse.system_user],
      )
    end

    it "links the staff action log to the reviewable when passed via opts" do
      reviewable = Fabricate(:reviewable_flagged_post, target_created_by: user)

      expect { UserSilencer.silence(user, admin, reviewable_id: reviewable.id) }.to change {
        UserHistory.where(
          action: UserHistory.actions[:silence_user],
          reviewable_id: reviewable.id,
        ).count
      }.by(1)
    end

    context "with a plugin hook" do
      before do
        @override_silence_message = ->(opts) do
          opts[:silence_message_params][:message_title] = "override title"
          opts[:silence_message_params][:message_raw] = "override raw"
        end

        DiscourseEvent.on(:user_silenced, &@override_silence_message)
      end

      after { DiscourseEvent.off(:user_silenced, &@override_silence_message) }

      it "allows the message to be overridden" do
        UserSilencer.silence(user, admin)
        # force a reload in case instance has no posts
        system_user = User.find(Discourse::SYSTEM_USER_ID)

        post = system_user.posts.order("posts.id desc").first

        expect(post.topic.title).to eq("override title")
        expect(post.raw).to eq("override raw")
      end

      context "when the dsa_reporting_enabled site setting is enabled" do
        before do
          SiteSetting.dsa_reporting_enabled = true
          SiteSetting.dsa_moderation_appeal_email = "appeals@example.com"
        end

        it "includes appeal instructions in plugin customized messages" do
          UserSilencer.silence(user, admin, message: :plugin_silence_notice)
          # force a reload in case instance has no posts
          system_user = User.find(Discourse::SYSTEM_USER_ID)

          post = system_user.posts.order("posts.id desc").first

          expect(post.topic.title).to eq("override title")
          expect(post.raw).to eq(
            "override raw\n\nTo appeal this decision, contact appeals@example.com",
          )
        end
      end
    end

    context "with an anonymous shadow" do
      before { SiteSetting.allow_anonymous_mode = true }

      it "silences the account behind the shadow and reports the shadow" do
        events =
          DiscourseEvent.track_events(:user_silenced) do
            expect(UserSilencer.silence(shadow, admin, keep_posts: true)).to eq(true)
          end

        expect(user.reload).to be_silenced
        expect(shadow.reload).to be_silenced
        expect(shadow[:silenced_till]).to be_nil
        expect(events.map { it[:params].first[:user] }).to eq([shadow])
        expect(
          UserHistory.where(action: UserHistory.actions[:silence_user]).pluck(:target_user_id),
        ).to eq([shadow.id])
        expect(shadow.topics_allowed.count).to eq(1)
        expect(user.topics_allowed.count).to eq(0)
      end

      it "names the shadow when telling moderators about an automatic silence" do
        SiteSetting.notify_mods_when_user_silenced = true

        UserSilencer.auto_silence(shadow, Discourse.system_user, reason: "spam")

        expect(user.reload).to be_silenced
        message = TopicAllowedGroup.find_by!(group_id: Group::AUTO_GROUPS[:moderators]).topic
        expect(message.first_post.raw).to include(shadow.username).and exclude(user.username)
      end

      it "does nothing when the account behind the shadow is already silenced" do
        user.update!(silenced_till: 1.day.from_now)

        events =
          DiscourseEvent.track_events(:user_silenced) do
            expect(UserSilencer.silence(shadow, admin)).to eq(false)
          end

        expect(events).to be_empty
      end

      it "does not silence a staff account through its shadow" do
        user.update!(moderator: true)

        expect(UserSilencer.silence(shadow, admin)).to eq(false)
        expect(user.reload).not_to be_silenced
      end
    end
  end

  describe "unsilence" do
    it "only lifts an expired silence when asked to", :aggregate_failures do
      user.update!(silenced_till: 1.day.from_now)

      expect(UserSilencer.unsilence(user, admin, expired_only: true)).to eq(false)
      expect(user.reload).to be_silenced

      user.update!(silenced_till: 1.minute.ago)
      expect(UserSilencer.unsilence(user, admin, expired_only: true)).to eq(true)
    end

    it "unsilences the user correctly" do
      user.update!(silenced_till: 1.year.from_now)

      expect { UserSilencer.unsilence(user, admin) }.to change { user.reload.silenced? }

      # sends a message
      pm = user.topics_allowed.order("topics.id desc").first
      title = I18n.t("system_messages.unsilenced.subject_template")
      expect(pm.title).to eq(title)

      # logs it
      count =
        UserHistory.where(
          action: UserHistory.actions[:unsilence_user],
          acting_user_id: admin.id,
          target_user_id: user.id,
        ).count

      expect(count).to eq(1)
    end

    context "when the dsa_reporting_enabled site setting is enabled" do
      before do
        SiteSetting.dsa_reporting_enabled = true
        SiteSetting.dsa_moderation_appeal_email = "appeals@example.com"
      end

      it "includes appeal instructions in the unsilence notice" do
        user.update!(silenced_till: 1.year.from_now)

        UserSilencer.unsilence(user, admin)

        pm = user.topics_allowed.order("topics.id desc").first
        expect(pm.first_post.raw).to include("To appeal this decision, contact appeals@example.com")
      end
    end

    it "returns true when it unsilenced the user" do
      user.update!(silenced_till: 1.year.from_now)

      expect(UserSilencer.unsilence(user, admin)).to eq(true)
    end

    it "does nothing when the user was unsilenced since it was loaded" do
      user.update!(silenced_till: 1.year.from_now)
      User.where(id: user.id).update_all(silenced_till: nil)

      events =
        DiscourseEvent.track_events(:user_unsilenced) do
          expect(UserSilencer.unsilence(user, admin)).to eq(false)
        end

      expect(events).to be_empty
      expect(UserHistory.where(action: UserHistory.actions[:unsilence_user])).to be_empty
    end

    it "does nothing when the user is not silenced" do
      expect(UserSilencer.unsilence(user, admin)).to eq(false)

      expect(user.topics_allowed.count).to eq(0)
      expect(UserHistory.where(action: UserHistory.actions[:unsilence_user]).count).to eq(0)
    end

    it "is idempotent when called twice" do
      user.update!(silenced_till: 1.year.from_now)

      UserSilencer.unsilence(user, admin)
      UserSilencer.unsilence(user, admin)

      expect(UserHistory.where(action: UserHistory.actions[:unsilence_user]).count).to eq(1)
      expect(
        user
          .topics_allowed
          .where(title: I18n.t("system_messages.unsilenced.subject_template"))
          .count,
      ).to eq(1)
    end

    context "with an anonymous shadow" do
      before { SiteSetting.allow_anonymous_mode = true }

      it "unsilences the account behind the shadow and reports the shadow" do
        user.update!(silenced_till: 1.year.from_now)

        events =
          DiscourseEvent.track_events(:user_unsilenced) { UserSilencer.unsilence(shadow, admin) }

        expect(user.reload).not_to be_silenced
        expect(shadow.reload).not_to be_silenced
        expect(events.map { it[:params].first[:user] }).to eq([shadow])
        expect(
          UserHistory.where(action: UserHistory.actions[:unsilence_user]).pluck(:target_user_id),
        ).to eq([shadow.id])
        expect(shadow.topics_allowed.count).to eq(1)
        expect(user.topics_allowed.count).to eq(0)
      end

      it "does nothing when only the shadow's own column is set" do
        shadow.update_columns(silenced_till: 1.year.from_now)

        events =
          DiscourseEvent.track_events(:user_unsilenced) do
            expect(UserSilencer.unsilence(shadow, admin)).to eq(false)
          end

        expect(events).to be_empty
      end
    end
  end
end
