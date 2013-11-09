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
      finder.expects(:check_dominating_topic).once
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
        user.expects(:created_topic_count).returns(9)
        finder.check_education_message.should be_present
      end

      it "returns no message when the user has posted enough topics" do
        user.expects(:created_topic_count).returns(10)
        finder.check_education_message.should be_blank
      end
    end

    context 'creating reply' do
      let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'reply') }

      before do
        SiteSetting.stubs(:educate_until_posts).returns(10)
      end

      it "returns a message for a user who has not posted any topics" do
        user.expects(:post_count).returns(9)
        finder.check_education_message.should be_present
      end

      it "returns no message when the user has posted enough topics" do
        user.expects(:post_count).returns(10)
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
      user.stubs(:post_count).returns(11)

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


      it "does not give a message to users who are still in the 'education' phase" do
        user.stubs(:post_count).returns(9)
        finder.check_sequential_replies.should be_blank
      end

      it "doesn't notify a user it has already notified about sequential replies" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_sequential_replies], target_user_id: user.id, topic_id: topic.id )
        finder.check_sequential_replies.should be_blank
      end


      it "will notify you if it hasn't in the current topic" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_sequential_replies], target_user_id: user.id, topic_id: topic.id+1 )
        finder.check_sequential_replies.should be_present
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

  context '.check_dominating_topic' do
    let(:user) { Fabricate(:user) }
    let(:topic) { Fabricate(:topic) }

    before do
      SiteSetting.stubs(:educate_until_posts).returns(10)
      user.stubs(:post_count).returns(11)

      SiteSetting.stubs(:best_of_posts_required).returns(1)

      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: Fabricate(:user))

      SiteSetting.stubs(:sequential_replies_threshold).returns(2)
    end

    it "does not give a message for new topics" do
      finder = ComposerMessagesFinder.new(user, composerAction: 'createTopic')
      finder.check_dominating_topic.should be_blank
    end

    it "does not give a message without a topic id" do
      ComposerMessagesFinder.new(user, composerAction: 'reply').check_dominating_topic.should be_blank
    end

    context "reply" do
      let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'reply', topic_id: topic.id) }

      it "does not give a message to users who are still in the 'education' phase" do
        user.stubs(:post_count).returns(9)
        finder.check_dominating_topic.should be_blank
      end

      it "does not notify if the `best_of_posts_required` has not been reached" do
        SiteSetting.stubs(:best_of_posts_required).returns(100)
        finder.check_dominating_topic.should be_blank
      end

      it "doesn't notify a user it has already notified in this topic" do
        UserHistory.create!(action: UserHistory.actions[:notitied_about_dominating_topic], topic_id: topic.id, target_user_id: user.id )
        finder.check_dominating_topic.should be_blank
      end

      it "notifies a user if the topic is different" do
        UserHistory.create!(action: UserHistory.actions[:notitied_about_dominating_topic], topic_id: topic.id+1, target_user_id: user.id )
        finder.check_dominating_topic.should be_present
      end

      it "doesn't notify a user if the topic has less than `best_of_posts_required` posts" do
        SiteSetting.stubs(:best_of_posts_required).returns(5)
        finder.check_dominating_topic.should be_blank
      end

      it "doesn't notify a user if they've posted less than the percentage" do
        SiteSetting.stubs(:dominating_topic_minimum_percent).returns(100)
        finder.check_dominating_topic.should be_blank
      end

      it "doesn't notify you if it's your own topic" do
        topic.update_column(:user_id, user.id)
        finder.check_dominating_topic.should be_blank
      end

      context "success" do
        let!(:message) { finder.check_dominating_topic }

        it "returns a message" do
          message.should be_present
        end

        it "creates a notitied_about_dominating_topic log" do
          UserHistory.exists_for_user?(user, :notitied_about_dominating_topic).should be_true
        end

      end
    end

  end

end

