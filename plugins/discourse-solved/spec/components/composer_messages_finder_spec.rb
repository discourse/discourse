# encoding: utf-8
# frozen_string_literal: true

require "composer_messages_finder"

describe ComposerMessagesFinder do
  describe ".check_topic_is_solved" do
    fab!(:user)
    fab!(:topic, :topic_with_op)
    fab!(:post) { Fabricate(:post, topic: topic, user: Fabricate(:user)) }

    before do
      SiteSetting.disable_solved_education_message = false
      SiteSetting.allow_solved_on_all_topics = true
    end

    it "does not show message without a topic id" do
      expect(
        described_class.new(user, composer_action: "createTopic").check_topic_is_solved,
      ).to be_blank
      expect(described_class.new(user, composer_action: "reply").check_topic_is_solved).to be_blank
    end

    describe "a reply" do
      it "does not show message if topic is not solved" do
        expect(
          described_class.new(
            user,
            composer_action: "reply",
            topic_id: topic.id,
          ).check_topic_is_solved,
        ).to be_blank
      end

      it "does not show message if disable_solved_education_message is true" do
        SiteSetting.disable_solved_education_message = true
        DiscourseSolved::AcceptAnswer.call!(
          params: {
            post_id: post.id,
          },
          guardian: Discourse.system_user.guardian,
        )
        expect(
          described_class.new(
            user,
            composer_action: "reply",
            topic_id: topic.id,
          ).check_topic_is_solved,
        ).to be_blank
      end

      it "shows message if the topic is solved" do
        DiscourseSolved::AcceptAnswer.call!(
          params: {
            post_id: post.id,
          },
          guardian: Discourse.system_user.guardian,
        )
        message =
          described_class.new(
            user,
            composer_action: "reply",
            topic_id: topic.id,
          ).check_topic_is_solved
        expect(message).not_to be_blank
        expect(message[:body]).to include("This topic has been solved")
      end
    end
  end
end
