# frozen_string_literal: true

require "rails_helper"

describe PostVotingVote do
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user)
  fab!(:post_1) { Fabricate(:post, topic: topic, user: user) }
  fab!(:tag)

  before { SiteSetting.post_voting_enabled = true }

  describe "validations" do
    context "with posts" do
      it "ensures votes cannot be created when qa is disabled" do
        SiteSetting.post_voting_enabled = false

        vote =
          PostVotingVote.new(votable: post, user: user, direction: PostVotingVote.directions[:up])

        expect(vote.valid?).to eq(false)

        expect(vote.errors.full_messages).to contain_exactly(
          I18n.t("post.post_voting.errors.post_voting_not_enabled"),
        )
      end

      it "ensures that only posts in reply to other posts cannot be voted on" do
        post.update!(post_number: 2, reply_to_post_number: 1)

        vote =
          PostVotingVote.new(votable: post, user: user, direction: PostVotingVote.directions[:up])

        expect(vote.valid?).to eq(false)

        expect(vote.errors.full_messages).to contain_exactly(
          I18n.t("post.post_voting.errors.voting_not_permitted"),
        )
      end

      it "ensures that votes can only be created for valid polymorphic types" do
        vote =
          PostVotingVote.new(
            votable: post.topic,
            user: user,
            direction: PostVotingVote.directions[:up],
          )

        expect(vote.valid?).to eq(false)
        expect(vote.errors[:votable_type].present?).to eq(true)
      end

      it "ensures that self voting is not allowed" do
        vote =
          PostVotingVote.new(votable: post_1, user: user, direction: PostVotingVote.directions[:up])

        expect(vote.valid?).to eq(false)
        expect(vote.errors.full_messages).to contain_exactly(
          I18n.t("post.post_voting.errors.self_voting_not_permitted"),
        )
      end
    end

    context "when commenting" do
      fab!(:comment) { Fabricate(:post_voting_comment, post: post) }

      it "ensures vote cannot be created on a comment when qa is disabled" do
        SiteSetting.post_voting_enabled = false
        comment.reload

        vote =
          PostVotingVote.new(
            votable: comment,
            user: user,
            direction: PostVotingVote.directions[:up],
          )

        expect(vote.valid?).to eq(false)

        expect(vote.errors.full_messages).to contain_exactly(
          I18n.t("post.post_voting.errors.post_voting_not_enabled"),
        )
      end

      it "ensures vote cannot be created on a comment when it is a downvote" do
        vote =
          PostVotingVote.new(
            votable: comment,
            user: user,
            direction: PostVotingVote.directions[:down],
          )

        expect(vote.valid?).to eq(false)

        expect(vote.errors.full_messages).to contain_exactly(
          I18n.t("post.post_voting.errors.comment_cannot_be_downvoted"),
        )
      end
    end
  end

  describe "#direction" do
    it "ensures inclusion of values" do
      vote = PostVotingVote.new(votable: post, user: user)

      vote.direction = "up"

      expect(vote.valid?).to eq(true)

      vote.direction = "down"

      expect(vote.valid?).to eq(true)

      vote.direction = "somethingelse"

      expect(vote.valid?).to eq(false)
    end
  end
end
