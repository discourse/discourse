# encoding: utf-8
require 'spec_helper'
require 'composer_messages_finder'

describe ComposerMessagesFinder do

  context "delegates work" do
    let(:user) { Fabricate.build(:user) }
    let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'createTopic') }

    it "calls all the message finders" do
      finder.expects(:check_education_message).once
      finder.expects(:check_avatar_notification).once
      finder.expects(:check_sequential_replies).once
      finder.find
    end

  end

  context '.check_education_message' do
    let(:user) { Fabricate.build(:user) }

    context 'creating topic' do
      let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'createTopic') }

      before do
        SiteSetting.stubs(:educate_until_posts).returns(10)
      end

      it "returns a message for a user who has not posted any topics" do
        user.expects(:created_topic_count).returns(10)
        finder.check_education_message.should be_present
      end

      it "returns no message when the user has posted enough topics" do
        user.expects(:created_topic_count).returns(11)
        finder.check_education_message.should be_blank
      end
    end

    context 'creating reply' do
      let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'reply') }

      before do
        SiteSetting.stubs(:educate_until_posts).returns(10)
      end

      it "returns a message for a user who has not posted any topics" do
        user.expects(:topic_reply_count).returns(10)
        finder.check_education_message.should be_present
      end

      it "returns no message when the user has posted enough topics" do
        user.expects(:topic_reply_count).returns(11)
        finder.check_education_message.should be_blank
      end
    end

  end

  context '.check_avatar_notification' do
    let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'createTopic') }
    let(:user) { Fabricate(:user) }

    context "a user who we haven't checked for an avatar yet" do
      it "returns no avatar message" do
        finder.check_avatar_notification.should be_blank
      end
    end

    context "a user who has been checked for a custom avatar" do
      before do
        UserHistory.create!(action: UserHistory.actions[:checked_for_custom_avatar], target_user_id: user.id )
      end

      context "success" do
        let!(:message) { finder.check_avatar_notification }

        it "returns an avatar upgrade message" do
          message.should be_present
        end

        it "creates a notified_about_avatar log" do
          UserHistory.exists_for_user?(user, :notified_about_avatar).should be_true
        end
      end

      it "doesn't return notifications for new users" do
        user.trust_level = TrustLevel.levels[:newuser]
        finder.check_avatar_notification.should be_blank
      end

      it "doesn't return notifications for users who have custom avatars" do
        user.user_stat.has_custom_avatar = true
        finder.check_avatar_notification.should be_blank
      end

      it "doesn't notify users who have been notified already" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_avatar], target_user_id: user.id )
        finder.check_avatar_notification.should be_blank
      end

    end
  end

  context '.check_sequential_replies' do
    let(:user) { Fabricate(:user) }
    let(:topic) { Fabricate(:topic) }

    before do
      SiteSetting.stubs(:educate_until_posts).returns(10)
      user.topic_reply_count = 11

      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: user)

      SiteSetting.stubs(:sequential_replies_threshold).returns(2)
    end

    it "does not give a message for new topics" do
      finder = ComposerMessagesFinder.new(user, composerAction: 'createTopic')
      finder.check_sequential_replies.should be_blank
    end

    it "does not give a message without a topic id" do
      ComposerMessagesFinder.new(user, composerAction: 'reply').check_sequential_replies.should be_blank
    end

    context "reply" do
      let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'reply', topic_id: topic.id) }

      it "does not give a message to new users" do
        user.trust_level = TrustLevel.levels[:newuser]
        finder.check_sequential_replies.should be_blank
      end

      it "does not give a message to users who are still in the 'education' phase" do
        user.topic_reply_count = 10
        finder.check_sequential_replies.should be_blank
      end

      it "doesn't notify a user it has already notified about sequential replies" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_sequential_replies], target_user_id: user.id )
        finder.check_sequential_replies.should be_blank
      end

      it "doesn't notify a user who has less than the `sequential_replies_threshold` threshold posts" do
        SiteSetting.stubs(:sequential_replies_threshold).returns(5)
        finder.check_sequential_replies.should be_blank
      end

      it "doesn't notify a user if another user posted" do
        Fabricate(:post, topic: topic, user: Fabricate(:user))
        finder.check_sequential_replies.should be_blank
      end

      context "success" do
        let!(:message) { finder.check_sequential_replies }

        it "returns a message" do
          message.should be_present
        end

        it "creates a notified_about_sequential_replies log" do
          UserHistory.exists_for_user?(user, :notified_about_sequential_replies).should be_true
        end

      end
    end

  end

end

