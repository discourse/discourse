# encoding: utf-8
require 'rails_helper'
require 'composer_messages_finder'

describe ComposerMessagesFinder do

  context "delegates work" do
    let(:user) { Fabricate.build(:user) }
    let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'createTopic') }

    it "calls all the message finders" do
      finder.expects(:check_education_message).once
      finder.expects(:check_new_user_many_replies).once
      finder.expects(:check_avatar_notification).once
      finder.expects(:check_sequential_replies).once
      finder.expects(:check_dominating_topic).once
      finder.expects(:check_reviving_old_topic).once
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
        expect(finder.check_education_message).to be_present
      end

      it "returns no message when the user has posted enough topics" do
        user.expects(:created_topic_count).returns(10)
        expect(finder.check_education_message).to be_blank
      end
    end

    context 'creating reply' do
      let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'reply') }

      before do
        SiteSetting.stubs(:educate_until_posts).returns(10)
      end

      it "returns a message for a user who has not posted any topics" do
        user.expects(:post_count).returns(9)
        expect(finder.check_education_message).to be_present
      end

      it "returns no message when the user has posted enough topics" do
        user.expects(:post_count).returns(10)
        expect(finder.check_education_message).to be_blank
      end
    end
  end

  context '.check_new_user_many_replies' do
    let(:user) { Fabricate.build(:user) }

    context 'replying' do
      let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'reply') }

      it "has no message when `posted_too_much_in_topic?` is false" do
        user.expects(:posted_too_much_in_topic?).returns(false)
        expect(finder.check_new_user_many_replies).to be_blank
      end

      it "has a message when a user has posted too much" do
        user.expects(:posted_too_much_in_topic?).returns(true)
        expect(finder.check_new_user_many_replies).to be_present
      end
    end

  end

  context '.check_avatar_notification' do
    let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'createTopic') }
    let(:user) { Fabricate(:user) }

    context "success" do
      let!(:message) { finder.check_avatar_notification }

      it "returns an avatar upgrade message" do
        expect(message).to be_present
      end

      it "creates a notified_about_avatar log" do
        expect(UserHistory.exists_for_user?(user, :notified_about_avatar)).to eq(true)
      end
    end

    it "doesn't return notifications for new users" do
      user.trust_level = TrustLevel[0]
      expect(finder.check_avatar_notification).to be_blank
    end

    it "doesn't return notifications for users who have custom avatars" do
      user.uploaded_avatar_id = 1
      expect(finder.check_avatar_notification).to be_blank
    end

    it "doesn't notify users who have been notified already" do
      UserHistory.create!(action: UserHistory.actions[:notified_about_avatar], target_user_id: user.id )
      expect(finder.check_avatar_notification).to be_blank
    end

    it "doesn't notify users if 'disable_avatar_education_message' setting is enabled" do
      SiteSetting.disable_avatar_education_message = true
      expect(finder.check_avatar_notification).to be_blank
    end

    it "doesn't notify users if 'sso_overrides_avatar' setting is enabled" do
      SiteSetting.sso_overrides_avatar = true
      expect(finder.check_avatar_notification).to be_blank
    end

    it "doesn't notify users if 'allow_uploaded_avatars' setting is disabled" do
      SiteSetting.allow_uploaded_avatars = false
      expect(finder.check_avatar_notification).to be_blank
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
      expect(finder.check_sequential_replies).to be_blank
    end

    it "does not give a message without a topic id" do
      expect(ComposerMessagesFinder.new(user, composerAction: 'reply').check_sequential_replies).to be_blank
    end

    context "reply" do
      let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'reply', topic_id: topic.id) }

      it "does not give a message to users who are still in the 'education' phase" do
        user.stubs(:post_count).returns(9)
        expect(finder.check_sequential_replies).to be_blank
      end

      it "doesn't notify a user it has already notified about sequential replies" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_sequential_replies], target_user_id: user.id, topic_id: topic.id )
        expect(finder.check_sequential_replies).to be_blank
      end

      it "will notify you if it hasn't in the current topic" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_sequential_replies], target_user_id: user.id, topic_id: topic.id+1 )
        expect(finder.check_sequential_replies).to be_present
      end

      it "doesn't notify a user who has less than the `sequential_replies_threshold` threshold posts" do
        SiteSetting.stubs(:sequential_replies_threshold).returns(5)
        expect(finder.check_sequential_replies).to be_blank
      end

      it "doesn't notify a user if another user posted" do
        Fabricate(:post, topic: topic, user: Fabricate(:user))
        expect(finder.check_sequential_replies).to be_blank
      end

      it "doesn't notify in message" do
        Topic.any_instance.expects(:private_message?).returns(true)
        expect(finder.check_sequential_replies).to be_blank
      end

      context "success" do
        let!(:message) { finder.check_sequential_replies }

        it "returns a message" do
          expect(message).to be_present
        end

        it "creates a notified_about_sequential_replies log" do
          expect(UserHistory.exists_for_user?(user, :notified_about_sequential_replies)).to eq(true)
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

      SiteSetting.stubs(:summary_posts_required).returns(1)

      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: Fabricate(:user))

      SiteSetting.stubs(:sequential_replies_threshold).returns(2)
    end

    it "does not give a message for new topics" do
      finder = ComposerMessagesFinder.new(user, composerAction: 'createTopic')
      expect(finder.check_dominating_topic).to be_blank
    end

    it "does not give a message without a topic id" do
      expect(ComposerMessagesFinder.new(user, composerAction: 'reply').check_dominating_topic).to be_blank
    end

    context "reply" do
      let(:finder) { ComposerMessagesFinder.new(user, composerAction: 'reply', topic_id: topic.id) }

      it "does not give a message to users who are still in the 'education' phase" do
        user.stubs(:post_count).returns(9)
        expect(finder.check_dominating_topic).to be_blank
      end

      it "does not notify if the `summary_posts_required` has not been reached" do
        SiteSetting.stubs(:summary_posts_required).returns(100)
        expect(finder.check_dominating_topic).to be_blank
      end

      it "doesn't notify a user it has already notified in this topic" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_dominating_topic], topic_id: topic.id, target_user_id: user.id )
        expect(finder.check_dominating_topic).to be_blank
      end

      it "notifies a user if the topic is different" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_dominating_topic], topic_id: topic.id+1, target_user_id: user.id )
        expect(finder.check_dominating_topic).to be_present
      end

      it "doesn't notify a user if the topic has less than `summary_posts_required` posts" do
        SiteSetting.stubs(:summary_posts_required).returns(5)
        expect(finder.check_dominating_topic).to be_blank
      end

      it "doesn't notify a user if they've posted less than the percentage" do
        SiteSetting.stubs(:dominating_topic_minimum_percent).returns(100)
        expect(finder.check_dominating_topic).to be_blank
      end

      it "doesn't notify you if it's your own topic" do
        topic.update_column(:user_id, user.id)
        expect(finder.check_dominating_topic).to be_blank
      end

      it "doesn't notify you in a private message" do
        topic.update_columns(category_id: nil, archetype: Archetype.private_message)
        expect(finder.check_dominating_topic).to be_blank
      end

      context "success" do
        let!(:message) { finder.check_dominating_topic }

        it "returns a message" do
          expect(message).to be_present
        end

        it "creates a notified_about_dominating_topic log" do
          expect(UserHistory.exists_for_user?(user, :notified_about_dominating_topic)).to eq(true)
        end

      end
    end

  end

  context '.check_reviving_old_topic' do
    let(:user)  { Fabricate(:user) }
    let(:topic) { Fabricate(:topic) }

    it "does not give a message without a topic id" do
      expect(described_class.new(user, composerAction: 'createTopic').check_reviving_old_topic).to be_blank
      expect(described_class.new(user, composerAction: 'reply').check_reviving_old_topic).to be_blank
    end

    context "a reply" do
      context "warn_reviving_old_topic_age is 180 days" do
        before do
          SiteSetting.stubs(:warn_reviving_old_topic_age).returns(180)
        end

        it "does not notify if last post is recent" do
          topic = Fabricate(:topic, last_posted_at: 1.hour.ago)
          expect(described_class.new(user, composerAction: 'reply', topic_id: topic.id).check_reviving_old_topic).to be_blank
        end

        it "notifies if last post is old" do
          topic = Fabricate(:topic, last_posted_at: 181.days.ago)
          expect(described_class.new(user, composerAction: 'reply', topic_id: topic.id).check_reviving_old_topic).not_to be_blank
        end
      end

      context "warn_reviving_old_topic_age is 0" do
        before do
          SiteSetting.stubs(:warn_reviving_old_topic_age).returns(0)
        end

        it "does not notify if last post is new" do
          topic = Fabricate(:topic, last_posted_at: 1.hour.ago)
          expect(described_class.new(user, composerAction: 'reply', topic_id: topic.id).check_reviving_old_topic).to be_blank
        end

        it "does not notify if last post is old" do
          topic = Fabricate(:topic, last_posted_at: 365.days.ago)
          expect(described_class.new(user, composerAction: 'reply', topic_id: topic.id).check_reviving_old_topic).to be_blank
        end
      end
    end
  end

end
