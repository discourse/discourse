# encoding: utf-8
require 'rails_helper'
require 'composer_messages_finder'

describe ComposerMessagesFinder do

  context "delegates work" do
    let(:user) { Fabricate.build(:user) }
    let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'createTopic') }

    it "calls all the message finders" do
      finder.expects(:check_education_message).once
      finder.expects(:check_new_user_many_replies).once
      finder.expects(:check_avatar_notification).once
      finder.expects(:check_sequential_replies).once
      finder.expects(:check_dominating_topic).once
      finder.expects(:check_reviving_old_topic).once
      finder.expects(:check_get_a_room).once
      finder.find
    end

  end

  context '.check_education_message' do
    let(:user) { Fabricate.build(:user) }

    context 'creating topic' do
      let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'createTopic') }

      before do
        SiteSetting.educate_until_posts = 10
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

    context 'private message' do
      let(:topic) { Fabricate(:private_message_topic) }

      context 'starting a new private message' do
        let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'createTopic', topic_id: topic.id) }

        it 'should return an empty string' do
          expect(finder.check_education_message).to eq(nil)
        end
      end

      context 'replying to a private message' do
        let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'reply', topic_id: topic.id) }

        it 'should return an empty string' do
          expect(finder.check_education_message).to eq(nil)
        end
      end
    end

    context 'creating reply' do
      let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'reply') }

      before do
        SiteSetting.educate_until_posts = 10
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
      let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'reply') }

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
    let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'createTopic') }
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
      UserHistory.create!(action: UserHistory.actions[:notified_about_avatar], target_user_id: user.id)
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
      SiteSetting.educate_until_posts = 10
      user.stubs(:post_count).returns(11)

      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: user, post_type: Post.types[:small_action])

      SiteSetting.sequential_replies_threshold = 2
    end

    it "does not give a message for new topics" do
      finder = ComposerMessagesFinder.new(user, composer_action: 'createTopic')
      expect(finder.check_sequential_replies).to be_blank
    end

    it "does not give a message without a topic id" do
      expect(ComposerMessagesFinder.new(user, composer_action: 'reply').check_sequential_replies).to be_blank
    end

    context "reply" do
      let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'reply', topic_id: topic.id) }

      it "does not give a message to users who are still in the 'education' phase" do
        user.stubs(:post_count).returns(9)
        expect(finder.check_sequential_replies).to be_blank
      end

      it "doesn't notify a user it has already notified about sequential replies" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_sequential_replies], target_user_id: user.id, topic_id: topic.id)
        expect(finder.check_sequential_replies).to be_blank
      end

      it "will notify you if it hasn't in the current topic" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_sequential_replies], target_user_id: user.id, topic_id: topic.id + 1)
        expect(finder.check_sequential_replies).to be_present
      end

      it "doesn't notify a user who has less than the `sequential_replies_threshold` threshold posts" do
        SiteSetting.sequential_replies_threshold = 5
        expect(finder.check_sequential_replies).to be_blank
      end

      it "doesn't notify a user if another user posted" do
        Fabricate(:post, topic: topic, user: Fabricate(:user))
        expect(finder.check_sequential_replies).to be_blank
      end

      it "doesn't notify in a message" do
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
      SiteSetting.educate_until_posts = 10
      user.stubs(:post_count).returns(11)

      SiteSetting.summary_posts_required = 1

      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: Fabricate(:user))

      SiteSetting.sequential_replies_threshold = 2
    end

    it "does not give a message for new topics" do
      finder = ComposerMessagesFinder.new(user, composer_action: 'createTopic')
      expect(finder.check_dominating_topic).to be_blank
    end

    it "does not give a message without a topic id" do
      expect(ComposerMessagesFinder.new(user, composer_action: 'reply').check_dominating_topic).to be_blank
    end

    context "reply" do
      let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'reply', topic_id: topic.id) }

      it "does not give a message to users who are still in the 'education' phase" do
        user.stubs(:post_count).returns(9)
        expect(finder.check_dominating_topic).to be_blank
      end

      it "does not notify if the `summary_posts_required` has not been reached" do
        SiteSetting.summary_posts_required = 100
        expect(finder.check_dominating_topic).to be_blank
      end

      it "doesn't notify a user it has already notified in this topic" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_dominating_topic], topic_id: topic.id, target_user_id: user.id)
        expect(finder.check_dominating_topic).to be_blank
      end

      it "notifies a user if the topic is different" do
        UserHistory.create!(action: UserHistory.actions[:notified_about_dominating_topic], topic_id: topic.id + 1, target_user_id: user.id)
        expect(finder.check_dominating_topic).to be_present
      end

      it "doesn't notify a user if the topic has less than `summary_posts_required` posts" do
        SiteSetting.summary_posts_required = 5
        expect(finder.check_dominating_topic).to be_blank
      end

      it "doesn't notify a user if they've posted less than the percentage" do
        SiteSetting.dominating_topic_minimum_percent = 100
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

  context '.check_get_a_room' do
    let(:user) { Fabricate(:user) }
    let(:other_user) { Fabricate(:user) }
    let(:third_user) { Fabricate(:user) }
    let(:topic) { Fabricate(:topic, user: other_user) }
    let(:op) { Fabricate(:post, topic_id: topic.id, user: other_user) }

    let!(:other_user_reply) do
      Fabricate(:post, topic: topic, user: third_user, reply_to_user_id: op.user_id)
    end

    let!(:first_reply) do
      Fabricate(:post, topic: topic, user: user, reply_to_user_id: op.user_id)
    end

    let!(:second_reply) do
      Fabricate(:post, topic: topic, user: user, reply_to_user_id: op.user_id)
    end

    before do
      SiteSetting.educate_until_posts = 10
      user.stubs(:post_count).returns(11)
      SiteSetting.get_a_room_threshold = 2
    end

    it "does not show the message for new topics" do
      finder = ComposerMessagesFinder.new(user, composer_action: 'createTopic')
      expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
    end

    it "does not give a message without a topic id" do
      expect(ComposerMessagesFinder.new(user, composer_action: 'reply').check_get_a_room(min_users_posted: 2)).to be_blank
    end

    context "reply" do
      let(:finder) { ComposerMessagesFinder.new(user, composer_action: 'reply', topic_id: topic.id, post_id: op.id) }

      it "does not give a message to users who are still in the 'education' phase" do
        user.stubs(:post_count).returns(9)
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      it "doesn't notify a user it has already notified about sequential replies" do
        UserHistory.create!(
          action: UserHistory.actions[:notified_about_get_a_room],
          target_user_id: user.id,
          topic_id: topic.id
        )
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      it "will notify you if it hasn't in the current topic" do
        UserHistory.create!(
          action: UserHistory.actions[:notified_about_get_a_room],
          target_user_id: user.id,
          topic_id: topic.id + 1
        )
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_present
      end

      it "won't notify you if you haven't had enough posts" do
        SiteSetting.get_a_room_threshold = 10
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      it "doesn't notify you if the posts aren't all to the same person" do
        first_reply.update_column(:reply_to_user_id, user.id)
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      it "doesn't notify you of posts to yourself" do
        first_reply.update_column(:reply_to_user_id, user.id)
        second_reply.update_column(:reply_to_user_id, user.id)
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      it "doesn't notify in a message" do
        topic.update_columns(category_id: nil, archetype: 'private_message')
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      it "doesn't notify when replying to a different user" do
        other_finder = ComposerMessagesFinder.new(
          user,
          composer_action: 'reply',
          topic_id: topic.id,
          post_id: other_user_reply.id
        )

        expect(other_finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      context "with a default min_users_posted value" do
        let!(:message) { finder.check_get_a_room }

        it "works as expected" do
          expect(message).to be_blank
        end
      end

      context "success" do
        let!(:message) { finder.check_get_a_room(min_users_posted: 2) }

        it "works as expected" do
          expect(message).to be_present
          expect(message[:id]).to eq('get_a_room')
          expect(message[:wait_for_typing]).to eq(true)
          expect(message[:templateName]).to eq('education')

          expect(UserHistory.exists_for_user?(user, :notified_about_get_a_room)).to eq(true)
        end
      end
    end

  end

  context '.check_reviving_old_topic' do
    let(:user)  { Fabricate(:user) }
    let(:topic) { Fabricate(:topic) }

    it "does not give a message without a topic id" do
      expect(described_class.new(user, composer_action: 'createTopic').check_reviving_old_topic).to be_blank
      expect(described_class.new(user, composer_action: 'reply').check_reviving_old_topic).to be_blank
    end

    context "a reply" do
      context "warn_reviving_old_topic_age is 180 days" do
        before do
          SiteSetting.warn_reviving_old_topic_age = 180
        end

        it "does not notify if last post is recent" do
          topic = Fabricate(:topic, last_posted_at: 1.hour.ago)
          expect(described_class.new(user, composer_action: 'reply', topic_id: topic.id).check_reviving_old_topic).to be_blank
        end

        it "notifies if last post is old" do
          topic = Fabricate(:topic, last_posted_at: 181.days.ago)
          message = described_class.new(user, composer_action: 'reply', topic_id: topic.id).check_reviving_old_topic
          expect(message).not_to be_blank
          expect(message[:body]).to match(/6 months ago/)
        end
      end

      context "warn_reviving_old_topic_age is 0" do
        before do
          SiteSetting.warn_reviving_old_topic_age = 0
        end

        it "does not notify if last post is new" do
          topic = Fabricate(:topic, last_posted_at: 1.hour.ago)
          expect(described_class.new(user, composer_action: 'reply', topic_id: topic.id).check_reviving_old_topic).to be_blank
        end

        it "does not notify if last post is old" do
          topic = Fabricate(:topic, last_posted_at: 365.days.ago)
          expect(described_class.new(user, composer_action: 'reply', topic_id: topic.id).check_reviving_old_topic).to be_blank
        end
      end
    end
  end

end
