# encoding: utf-8
# frozen_string_literal: true

require "composer_messages_finder"

RSpec.describe ComposerMessagesFinder do
  describe "delegates work" do
    let(:user) { Fabricate.build(:user) }
    let(:finder) { ComposerMessagesFinder.new(user, composer_action: "createTopic") }

    it "calls all the message finders" do
      finder.expects(:check_education_message).once
      finder.expects(:check_new_user_many_replies).once
      finder.expects(:check_dominating_topic).once
      finder.expects(:check_get_a_room).once
      finder.find
    end
  end

  describe ".check_education_message" do
    let(:user) { Fabricate.build(:user) }

    context "when creating topic" do
      let(:finder) { ComposerMessagesFinder.new(user, composer_action: "createTopic") }

      before { SiteSetting.educate_until_posts = 10 }

      it "returns a message for a user who has not posted any topics" do
        user.expects(:created_topic_count).returns(9)
        expect(finder.check_education_message).to be_present
      end

      it "returns no message when the user has posted enough topics" do
        user.expects(:created_topic_count).returns(10)
        expect(finder.check_education_message).to be_blank
      end
    end

    context "with private message" do
      fab!(:topic) { Fabricate(:private_message_topic) }

      context "when starting a new private message" do
        let(:finder) do
          ComposerMessagesFinder.new(user, composer_action: "createTopic", topic_id: topic.id)
        end

        it "should return an empty string" do
          expect(finder.check_education_message).to eq(nil)
        end
      end

      context "when replying to a private message" do
        let(:finder) do
          ComposerMessagesFinder.new(user, composer_action: "reply", topic_id: topic.id)
        end

        it "should return an empty string" do
          expect(finder.check_education_message).to eq(nil)
        end
      end
    end

    context "when creating reply" do
      let(:finder) { ComposerMessagesFinder.new(user, composer_action: "reply") }

      before { SiteSetting.educate_until_posts = 10 }

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

  describe ".check_new_user_many_replies" do
    let(:user) { Fabricate.build(:user) }

    context "when replying" do
      let(:finder) { ComposerMessagesFinder.new(user, composer_action: "reply") }

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

  describe ".check_dominating_topic" do
    fab!(:user)
    fab!(:topic)

    before do
      SiteSetting.educate_until_posts = 10
      user.stubs(:post_count).returns(11)

      SiteSetting.summary_posts_required = 1

      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: user)
      Fabricate(:post, topic: topic, user: Fabricate(:user))
    end

    it "does not give a message for new topics" do
      finder = ComposerMessagesFinder.new(user, composer_action: "createTopic")
      expect(finder.check_dominating_topic).to be_blank
    end

    it "does not give a message without a topic id" do
      expect(
        ComposerMessagesFinder.new(user, composer_action: "reply").check_dominating_topic,
      ).to be_blank
    end

    context "with reply" do
      let(:finder) do
        ComposerMessagesFinder.new(user, composer_action: "reply", topic_id: topic.id)
      end

      it "does not give a message to users who are still in the 'education' phase" do
        user.stubs(:post_count).returns(9)
        expect(finder.check_dominating_topic).to be_blank
      end

      it "does not notify if the `summary_posts_required` has not been reached" do
        SiteSetting.summary_posts_required = 100
        expect(finder.check_dominating_topic).to be_blank
      end

      it "doesn't notify a user it has already notified in this topic" do
        UserHistory.create!(
          action: UserHistory.actions[:notified_about_dominating_topic],
          topic_id: topic.id,
          target_user_id: user.id,
        )
        expect(finder.check_dominating_topic).to be_blank
      end

      it "notifies a user if the topic is different" do
        UserHistory.create!(
          action: UserHistory.actions[:notified_about_dominating_topic],
          topic_id: topic.id + 1,
          target_user_id: user.id,
        )
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

      context "with success" do
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

  describe "#dont_feed_the_trolls" do
    fab!(:user)
    fab!(:author) { Fabricate(:user) }
    fab!(:other_user) { Fabricate(:user) }
    fab!(:third_user) { Fabricate(:user) }
    fab!(:topic) { Fabricate(:topic, user: author) }
    fab!(:original_post) { Fabricate(:post, topic: topic, user: author) }
    fab!(:unflagged_post) { Fabricate(:post, topic: topic, user: author) }
    fab!(:self_flagged_post) { Fabricate(:post, topic: topic, user: author) }
    fab!(:under_flagged_post) { Fabricate(:post, topic: topic, user: author) }
    fab!(:over_flagged_post) { Fabricate(:post, topic: topic, user: author) }
    fab!(:resolved_flag_post) { Fabricate(:post, topic: topic, user: author) }

    before { SiteSetting.dont_feed_the_trolls_threshold = 2 }

    it "does not show a message for unflagged posts" do
      finder =
        ComposerMessagesFinder.new(
          user,
          composer_action: "reply",
          topic_id: topic.id,
          post_id: unflagged_post.id,
        )
      expect(finder.check_dont_feed_the_trolls).to be_blank
    end

    it "shows a message when the replier has already flagged the post" do
      Fabricate(:flag_post_action, post: self_flagged_post, user: user)
      finder =
        ComposerMessagesFinder.new(
          user,
          composer_action: "reply",
          topic_id: topic.id,
          post_id: self_flagged_post.id,
        )
      expect(finder.check_dont_feed_the_trolls).to be_present
    end

    it "shows a message when replying to flagged topic (first post)" do
      Fabricate(:flag_post_action, post: original_post, user: user)
      finder = ComposerMessagesFinder.new(user, composer_action: "reply", topic_id: topic.id)
      expect(finder.check_dont_feed_the_trolls).to be_present
    end

    it "does not show a message when not enough others have flagged the post" do
      Fabricate(:flag_post_action, post: under_flagged_post, user: other_user)
      finder =
        ComposerMessagesFinder.new(
          user,
          composer_action: "reply",
          topic_id: topic.id,
          post_id: under_flagged_post.id,
        )
      expect(finder.check_dont_feed_the_trolls).to be_blank
    end

    it "does not show a message when the flag has already been resolved" do
      SiteSetting.dont_feed_the_trolls_threshold = 1

      Fabricate(
        :flag_post_action,
        post: resolved_flag_post,
        user: other_user,
        disagreed_at: 1.hour.ago,
      )
      finder =
        ComposerMessagesFinder.new(
          user,
          composer_action: "reply",
          topic_id: topic.id,
          post_id: resolved_flag_post.id,
        )
      expect(finder.check_dont_feed_the_trolls).to be_blank
    end

    it "shows a message when enough others have already flagged the post" do
      Fabricate(:flag_post_action, post: over_flagged_post, user: other_user)
      Fabricate(:flag_post_action, post: over_flagged_post, user: third_user)
      finder =
        ComposerMessagesFinder.new(
          user,
          composer_action: "reply",
          topic_id: topic.id,
          post_id: over_flagged_post.id,
        )
      expect(finder.check_dont_feed_the_trolls).to be_present
    end

    it "safely returns from not finding a post" do
      finder = ComposerMessagesFinder.new(user, composer_action: "reply", topic_id: nil)
      expect(finder.check_dont_feed_the_trolls).to be_blank
    end
  end

  describe ".check_get_a_room" do
    fab!(:user)
    fab!(:other_user) { Fabricate(:user) }
    fab!(:third_user) { Fabricate(:user) }
    fab!(:topic) { Fabricate(:topic, user: other_user) }
    fab!(:op) { Fabricate(:post, topic_id: topic.id, user: other_user) }

    fab!(:other_user_reply) do
      Fabricate(:post, topic: topic, user: third_user, reply_to_user_id: op.user_id)
    end

    fab!(:first_reply) { Fabricate(:post, topic: topic, user: user, reply_to_user_id: op.user_id) }

    fab!(:second_reply) { Fabricate(:post, topic: topic, user: user, reply_to_user_id: op.user_id) }

    before do
      SiteSetting.educate_until_posts = 10
      user.stubs(:post_count).returns(11)
      SiteSetting.get_a_room_threshold = 2
      SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
    end

    context "when user can't send private messages" do
      fab!(:group)

      before { SiteSetting.personal_message_enabled_groups = group.id }

      it "does not show the message" do
        expect(
          ComposerMessagesFinder.new(
            user,
            composer_action: "reply",
            topic_id: topic.id,
            post_id: op.id,
          ).check_get_a_room(min_users_posted: 2),
        ).to be_blank
      end
    end

    it "does not show the message for new topics" do
      finder = ComposerMessagesFinder.new(user, composer_action: "createTopic")
      expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
    end

    it "does not give a message without a topic id" do
      expect(
        ComposerMessagesFinder.new(user, composer_action: "reply").check_get_a_room(
          min_users_posted: 2,
        ),
      ).to be_blank
    end

    it "does not give a message if the topic's category is read_restricted" do
      topic.category.update(read_restricted: true)
      finder =
        ComposerMessagesFinder.new(
          user,
          composer_action: "reply",
          topic_id: topic.id,
          post_id: op.id,
        )
      finder.check_get_a_room(min_users_posted: 2)
      expect(UserHistory.exists_for_user?(user, :notified_about_get_a_room)).to eq(false)
    end

    context "with reply" do
      let(:finder) do
        ComposerMessagesFinder.new(
          user,
          composer_action: "reply",
          topic_id: topic.id,
          post_id: op.id,
        )
      end

      it "does not give a message to users who are still in the 'education' phase" do
        user.stubs(:post_count).returns(9)
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      it "doesn't notify a user it has already notified about sequential replies" do
        UserHistory.create!(
          action: UserHistory.actions[:notified_about_get_a_room],
          target_user_id: user.id,
          topic_id: topic.id,
        )
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      it "will notify you if it hasn't in the current topic" do
        UserHistory.create!(
          action: UserHistory.actions[:notified_about_get_a_room],
          target_user_id: user.id,
          topic_id: topic.id + 1,
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
        topic.update_columns(category_id: nil, archetype: "private_message")
        expect(finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      it "doesn't notify when replying to a different user" do
        other_finder =
          ComposerMessagesFinder.new(
            user,
            composer_action: "reply",
            topic_id: topic.id,
            post_id: other_user_reply.id,
          )

        expect(other_finder.check_get_a_room(min_users_posted: 2)).to be_blank
      end

      context "with a default min_users_posted value" do
        let!(:message) { finder.check_get_a_room }

        it "works as expected" do
          expect(message).to be_blank
        end
      end

      context "with success" do
        let!(:message) { finder.check_get_a_room(min_users_posted: 2) }

        it "works as expected" do
          expect(message).to be_present
          expect(message[:id]).to eq("get_a_room")
          expect(message[:wait_for_typing]).to eq(true)
          expect(message[:templateName]).to eq("get-a-room")

          expect(UserHistory.exists_for_user?(user, :notified_about_get_a_room)).to eq(true)
        end
      end
    end
  end

  context "when editing a post" do
    fab!(:user)
    fab!(:topic) { Fabricate(:post).topic }

    let!(:post) do
      PostCreator.create!(user, topic_id: topic.id, post_number: 1, raw: "omg my first post")
    end

    let(:edit_post_finder) { ComposerMessagesFinder.new(user, composer_action: "edit") }

    before { SiteSetting.educate_until_posts = 2 }

    it "returns nothing even if it normally would" do
      expect(edit_post_finder.find).to eq(nil)
    end
  end

  describe "#user_not_seen_in_a_while" do
    fab!(:user_1) { Fabricate(:user, last_seen_at: 3.years.ago) }
    fab!(:user_2) { Fabricate(:user, last_seen_at: 2.years.ago) }
    fab!(:user_3) { Fabricate(:user, last_seen_at: 6.months.ago) }

    before { SiteSetting.pm_warn_user_last_seen_months_ago = 24 }

    it "returns users that have not been seen recently" do
      users =
        ComposerMessagesFinder.user_not_seen_in_a_while(
          [user_1.username, user_2.username, user_3.username],
        )
      expect(users).to contain_exactly(user_1.username, user_2.username)
    end

    it "accounts for pm_warn_user_last_seen_months_ago site setting" do
      SiteSetting.pm_warn_user_last_seen_months_ago = 30
      users =
        ComposerMessagesFinder.user_not_seen_in_a_while(
          [user_1.username, user_2.username, user_3.username],
        )
      expect(users).to contain_exactly(user_1.username)
    end
  end
end
