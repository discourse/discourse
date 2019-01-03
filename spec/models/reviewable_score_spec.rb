require 'rails_helper'

RSpec.describe ReviewableScore, type: :model do

  context "transitions" do
    let(:user) { Fabricate(:user, trust_level: 3) }
    let(:post) { Fabricate(:post) }
    let(:moderator) { Fabricate(:moderator) }

    it "scores agreements properly" do
      reviewable = PostActionCreator.off_topic(user, post).reviewable
      rs = reviewable.reviewable_scores.find_by(user: user)
      expect(rs.score).to eq(4.0)
      expect(reviewable.score).to eq(4.0)
      expect(reviewable.latest_score).to be_present

      reviewable.perform(moderator, :agree_and_keep)
      expect(rs.reload).to be_agreed
      expect(rs.reviewed_by).to eq(moderator)
      expect(rs.reviewed_at).to be_present
      expect(reviewable.score).to eq(0.0)
    end

    it "scores disagreements properly" do
      reviewable = PostActionCreator.spam(user, post).reviewable
      rs = reviewable.reviewable_scores.find_by(user: user)
      expect(rs).to be_pending
      expect(rs.score).to eq(4.0)
      expect(reviewable.score).to eq(4.0)
      expect(reviewable.latest_score).to be_present

      reviewable.perform(moderator, :disagree)
      expect(rs.reload).to be_disagreed
      expect(rs.reviewed_by).to eq(moderator)
      expect(rs.reviewed_at).to be_present
      expect(reviewable.score).to eq(0.0)
    end

    it "increases the score by the post action type's score bonus" do
      PostActionType.where(name_key: 'spam').update_all(score_bonus: 2.25)
      reviewable = PostActionCreator.spam(user, post).reviewable
      score = reviewable.reviewable_scores.find_by(user: user)
      expect(score).to be_pending
      expect(score.score).to eq(6.25)
      expect(reviewable.score).to eq(6.25)
    end
  end

  describe "overall score" do
    let(:user0) { Fabricate(:user, trust_level: 1) }
    let(:user1) { Fabricate(:user, trust_level: 2) }
    let(:user2) { Fabricate(:user, trust_level: 3) }
    let(:moderator) { Fabricate(:moderator) }
    let(:post) { Fabricate(:post) }
    let(:topic) { post.topic }

    it "gives a bonus for take_action" do
      result = PostActionCreator.new(
        moderator,
        post,
        PostActionType.types[:spam],
        take_action: true
      ).perform

      expect(result.reviewable_score.take_action_bonus).to eq(5.0)
      expect(result.reviewable.score).to eq(11.0)
      expect(topic.reviewable_score).to eq(11.0)
    end

    it "is the total of the pending reviewable scores" do
      reviewable = PostActionCreator.spam(user0, post).reviewable
      expect(reviewable.score).to eq(2.0)
      expect(topic.reload.reviewable_score).to eq(2.0)

      reviewable = PostActionCreator.inappropriate(user1, post).reviewable
      expect(reviewable.score).to eq(5.0)
      expect(topic.reload.reviewable_score).to eq(5.0)

      reviewable.perform(Discourse.system_user, :agree_and_keep)
      expect(reviewable.score).to eq(0.0)
      expect(topic.reload.reviewable_score).to eq(0.0)

      reviewable = PostActionCreator.off_topic(user2, post).reviewable
      expect(reviewable.score).to eq(4.0)
      expect(topic.reload.reviewable_score).to eq(4.0)
    end
  end

  describe ".user_accuracy_bonus" do
    let(:user) { Fabricate(:user) }
    let(:user_stat) { user.user_stat }

    it "returns 0 for a user with no flags" do
      expect(ReviewableScore.user_accuracy_bonus(user)).to eq(0.0)
    end

    it "returns 0 until the user has made more than 5 flags" do
      user_stat.flags_agreed = 4
      user_stat.flags_disagreed = 1
      expect(ReviewableScore.user_accuracy_bonus(user)).to eq(0.0)
    end

    it "returns (agreed_flags / total) * 5.0" do
      user_stat.flags_agreed = 4
      user_stat.flags_disagreed = 2
      expect(ReviewableScore.user_accuracy_bonus(user).floor(2)).to eq(3.33)

      user_stat.flags_agreed = 121
      user_stat.flags_disagreed = 44
      user_stat.flags_ignored = 4
      expect(ReviewableScore.user_accuracy_bonus(user).floor(2)).to eq(3.57)
    end

  end

  describe ".user_flag_score" do
    context "a user with no flags" do
      it "returns 1.0 + trust_level" do
        expect(ReviewableScore.user_flag_score(Fabricate.build(:user, trust_level: 2))).to eq(3.0)
        expect(ReviewableScore.user_flag_score(Fabricate.build(:user, trust_level: 3))).to eq(4.0)
      end

      it "returns 6.0 for staff" do
        expect(ReviewableScore.user_flag_score(Fabricate.build(:moderator, trust_level: 2))).to eq(6.0)
        expect(ReviewableScore.user_flag_score(Fabricate.build(:admin, trust_level: 1))).to eq(6.0)
      end
    end

    context "a user with some flags" do
      let(:user) { Fabricate(:user) }
      let(:user_stat) { user.user_stat }

      it "returns 1.0 + trust_level + accuracy_bonus" do
        user.trust_level = 2
        user_stat.flags_agreed = 12
        user_stat.flags_disagreed = 2
        user_stat.flags_ignored = 2
        expect(ReviewableScore.user_flag_score(user)).to eq(6.75)
      end
    end
  end

end
