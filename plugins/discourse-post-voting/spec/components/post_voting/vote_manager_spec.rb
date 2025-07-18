# frozen_string_literal: true

require "rails_helper"

describe PostVoting::VoteManager do
  fab!(:user)
  fab!(:user_2) { Fabricate(:user) }
  fab!(:user_3) { Fabricate(:user) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:topic_post) { Fabricate(:post, topic: topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:up) { PostVotingVote.directions[:up] }
  fab!(:down) { PostVotingVote.directions[:down] }

  before { SiteSetting.post_voting_enabled = true }

  describe ".vote" do
    it "can create an upvote" do
      message =
        MessageBus
          .track_publish("/topic/#{post.topic_id}") do
            PostVoting::VoteManager.vote(post, user, direction: up)
          end
          .first

      expect(PostVotingVote.exists?(votable: post, user: user, direction: up)).to eq(true)

      expect(post.qa_vote_count).to eq(1)

      expect(message.data[:id]).to eq(post.id)
      expect(message.data[:post_voting_user_voted_id]).to eq(user.id)
      expect(message.data[:post_voting_vote_count]).to eq(1)
      expect(message.data[:post_voting_user_voted_direction]).to eq(up)
      expect(message.data[:post_voting_has_votes]).to eq(true)
    end

    it "can create a downvote" do
      message =
        MessageBus
          .track_publish("/topic/#{post.topic_id}") do
            PostVoting::VoteManager.vote(post, user, direction: down)
          end
          .first

      expect(PostVotingVote.exists?(votable: post, user: user, direction: down)).to eq(true)

      expect(post.qa_vote_count).to eq(-1)

      expect(message.data[:id]).to eq(post.id)
      expect(message.data[:post_voting_user_voted_id]).to eq(user.id)
      expect(message.data[:post_voting_vote_count]).to eq(-1)
      expect(message.data[:post_voting_user_voted_direction]).to eq(down)
      expect(message.data[:post_voting_has_votes]).to eq(true)
    end

    it "can change an upvote to a downvote" do
      PostVoting::VoteManager.vote(post, user, direction: up)
      PostVoting::VoteManager.vote(post, user_2, direction: up)
      PostVoting::VoteManager.vote(post, user, direction: down)

      expect(post.qa_vote_count).to eq(0)
    end

    it "can change a downvote to upvote" do
      PostVoting::VoteManager.vote(post, user, direction: down)
      PostVoting::VoteManager.vote(post, user_2, direction: down)
      PostVoting::VoteManager.vote(post, user_3, direction: down)
      PostVoting::VoteManager.vote(post, user, direction: up)

      expect(post.qa_vote_count).to eq(-1)
    end
  end

  describe ".remove_vote" do
    it "should remove a user's upvote" do
      vote = PostVoting::VoteManager.vote(post, user, direction: up)

      message =
        MessageBus
          .track_publish("/topic/#{post.topic_id}") do
            PostVoting::VoteManager.remove_vote(vote.votable, vote.user)
          end
          .first

      expect(PostVotingVote.exists?(id: vote.id)).to eq(false)
      expect(vote.votable.qa_vote_count).to eq(0)

      expect(message.data[:id]).to eq(post.id)
      expect(message.data[:post_voting_user_voted_id]).to eq(user.id)
      expect(message.data[:post_voting_vote_count]).to eq(0)
      expect(message.data[:post_voting_user_voted_direction]).to eq(nil)
      expect(message.data[:post_voting_has_votes]).to eq(false)
    end

    it "should remove a user's downvote" do
      vote = PostVoting::VoteManager.vote(post, Fabricate(:user), direction: up)
      vote_2 = PostVoting::VoteManager.vote(post, Fabricate(:user), direction: up)
      vote_3 = PostVoting::VoteManager.vote(post, user, direction: down)

      message =
        MessageBus
          .track_publish("/topic/#{post.topic_id}") do
            expect do PostVoting::VoteManager.remove_vote(post, user) end.to change {
              vote.votable.reload.qa_vote_count
            }.from(1).to(2)
          end
          .first

      expect(PostVotingVote.exists?(id: vote_3.id)).to eq(false)
    end
  end

  describe ".bulk_remove_votes_by" do
    it "removes all votes by a user" do
      other_user_1 = Fabricate(:user)
      other_user_2 = Fabricate(:user)

      comment_1 = Fabricate(:post_voting_comment, post: post)
      comment_2 = Fabricate(:post_voting_comment, post: post)
      comment_3 = Fabricate(:post_voting_comment, post: topic_post)

      vote_1 = PostVoting::VoteManager.vote(post, user, direction: down)
      vote_2 = PostVoting::VoteManager.vote(topic_post, user, direction: up)
      vote_3 = PostVoting::VoteManager.vote(comment_1, user, direction: up)
      vote_4 = PostVoting::VoteManager.vote(comment_2, user, direction: up)

      vote_5 = PostVoting::VoteManager.vote(post, other_user_1, direction: down)
      vote_6 = PostVoting::VoteManager.vote(topic_post, other_user_1, direction: up)
      vote_7 = PostVoting::VoteManager.vote(comment_1, other_user_1, direction: up)
      vote_8 = PostVoting::VoteManager.vote(comment_3, other_user_2, direction: up)

      expect(PostVotingVote.exists?(id: [vote_1.id, vote_2.id, vote_3.id, vote_4.id])).to eq(true)
      expect(user.post_voting_votes.count).to eq(4)
      expect(PostVotingVote.count).to eq(8)

      expect(post.qa_vote_count).to eq(-2)
      expect(topic_post.qa_vote_count).to eq(2)
      expect(comment_1.qa_vote_count).to eq(2)
      expect(comment_2.qa_vote_count).to eq(1)
      expect(comment_3.qa_vote_count).to eq(1)

      PostVoting::VoteManager.bulk_remove_votes_by(user)

      expect(PostVotingVote.exists?(id: [vote_1.id, vote_2.id, vote_3.id, vote_4.id])).to eq(false)
      expect(PostVotingVote.exists?(id: [vote_5.id, vote_6.id, vote_7.id, vote_8.id])).to eq(true)
      expect(PostVotingVote.count).to eq(4)

      expect(post.reload.qa_vote_count).to eq(-1)
      expect(topic_post.reload.qa_vote_count).to eq(1)
      expect(comment_1.reload.qa_vote_count).to eq(1)
      expect(comment_2.reload.qa_vote_count).to eq(0)
      expect(comment_3.reload.qa_vote_count).to eq(1)
    end
  end
end
