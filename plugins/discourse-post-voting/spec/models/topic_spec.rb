# frozen_string_literal: true

require "rails_helper"

describe Topic do
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }

  fab!(:answers) { 5.times.map { Fabricate(:post, topic: topic) }.sort_by(&:post_number) }

  fab!(:comments) do
    answer = answers.first

    5.times.map { Fabricate(:post_voting_comment, post: answer) }.sort_by(&:created_at)
  end

  let(:up) { PostVotingVote.directions[:up] }

  describe "validations" do
    describe "#subtype" do
      it "should not allow Post Voting formatted topics to be created when post_voting_enabled site setting is not enabled" do
        SiteSetting.post_voting_enabled = false

        topic =
          Fabricate.build(:topic, archetype: Archetype.default, subtype: Topic::POST_VOTING_SUBTYPE)

        expect(topic.valid?).to eq(false)
        expect(topic.errors.full_messages).to eq(
          [I18n.t("topic.post_voting.errors.post_voting_not_enabled")],
        )
      end

      it "should not allow topic to change to Post Voting subtype once it has been created" do
        topic_2 = Fabricate(:topic)
        topic_2.subtype = Topic::POST_VOTING_SUBTYPE

        expect(topic_2.valid?).to eq(false)
        expect(topic_2.errors.full_messages).to eq(
          [I18n.t("topic.post_voting.errors.cannot_change_to_post_voting_subtype")],
        )
      end

      it "should only allow Post Voting subtype to be set on regular topics" do
        topic =
          Fabricate.build(:topic, archetype: Archetype.default, subtype: Topic::POST_VOTING_SUBTYPE)

        expect(topic.valid?).to eq(true)

        topic.archetype = Archetype.private_message

        expect(topic.valid?).to eq(false)
        expect(topic.errors.full_messages).to eq(
          [I18n.t("topic.post_voting.errors.subtype_not_allowed")],
        )
      end
    end
  end

  it "should return correct comments" do
    comment_ids = comments.map(&:id)
    topic_comment_ids = topic.comments.pluck(:id)

    expect(comment_ids).to eq(topic_comment_ids)
  end

  it "should return correct answers" do
    answer_ids = answers.map(&:id)
    topic_answer_ids = topic.answers.pluck(:id)

    expect(answer_ids).to eq(topic_answer_ids)
  end

  it "should return correct answer_count" do
    expect(topic.answers.size).to eq(answers.size)
  end

  it "should return correct last_answered_at" do
    expected = answers.last.created_at

    expect(topic.last_answered_at).to eq_time(expected)
  end

  it "should return correct last_commented_on" do
    expected = comments.last.created_at

    expect(topic.last_commented_on).to eq_time(expected)
  end

  it "should return correct last_answer_post_number" do
    expected = answers.last.post_number

    expect(topic.last_answer_post_number).to eq(expected)
  end

  it "should return correct last_answerer" do
    expected = answers.last.user.id

    expect(topic.last_answerer.id).to eq(expected)
  end

  describe ".post_voting_votes" do
    it "should return nil if user is blank" do
      expect(Topic.post_voting_votes(topic, nil)).to eq(nil)
    end

    it "should return nil if disabled" do
      SiteSetting.post_voting_enabled = false

      expect(Topic.post_voting_votes(topic, user)).to eq(nil)
    end

    it "should return voted post IDs" do
      expected =
        answers
          .first(3)
          .map do |a|
            PostVoting::VoteManager.vote(a, user, direction: up)

            a.id
          end
          .sort

      expect(Topic.post_voting_votes(topic, user).pluck(:votable_id)).to contain_exactly(*expected)
    end
  end
end
