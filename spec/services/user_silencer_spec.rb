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
  end
end
