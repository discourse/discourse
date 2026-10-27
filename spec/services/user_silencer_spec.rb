# frozen_string_literal: true

RSpec.describe UserSilencer do
  fab!(:user) { Fabricate(:user, trust_level: 0) }
  fab!(:post) { Fabricate(:post, user: user) }
  fab!(:admin)

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
  end

  describe "unsilence" do
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
  end
end
