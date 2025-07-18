# frozen_string_literal: true

require "rails_helper"

describe TopicView do
  fab!(:user)
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:post) { create_post(topic: topic) }

  fab!(:answer) { create_post(topic: topic) }
  fab!(:answer_2) { create_post(topic: topic) }
  let(:comment) { Fabricate(:post_voting_comment, post: answer) }
  let(:comment_2) { Fabricate(:post_voting_comment, post: answer) }
  let(:comment_3) { Fabricate(:post_voting_comment, post: post) }
  let(:vote) { Fabricate(:post_voting_vote, votable: answer, user: user) }

  let(:vote_2) do
    Fabricate(
      :post_voting_vote,
      votable: answer_2,
      user: user,
      direction: PostVotingVote.directions[:down],
    )
  end

  before do
    SiteSetting.post_voting_enabled = true
    vote
    vote_2
    comment
    comment_2
    comment_3
  end

  it "does not preload Post Voting related records for non-Post Voting topics" do
    topic_2 = Fabricate(:topic)
    topic_2_post = Fabricate(:post, topic: topic_2)
    Fabricate(:post, topic: topic_2, reply_to_post_number: topic_2_post.post_number)

    topic_view = TopicView.new(topic_2, user)

    expect(topic_view.comments).to eq(nil)
    expect(topic_view.comments_counts).to eq(nil)
    expect(topic_view.posts_user_voted).to eq(nil)
  end

  it "should preload comments, comments count, user voted status for a given topic" do
    PostVoting::VoteManager.vote(comment, user)
    PostVoting::VoteManager.vote(comment_2, comment_3.user)

    topic_view = TopicView.new(topic, user)

    expect(topic_view.comments[answer.id].map(&:id)).to contain_exactly(comment.id, comment_2.id)
    expect(topic_view.comments[post.id].map(&:id)).to contain_exactly(comment_3.id)

    expect(topic_view.comments_counts[answer.id]).to eq(2)
    expect(topic_view.comments_counts[post.id]).to eq(1)

    expect(topic_view.posts_user_voted).to eq(
      {
        answer.id => PostVotingVote.directions[:up],
        answer_2.id => PostVotingVote.directions[:down],
      },
    )

    expect(topic_view.comments_user_voted).to eq({ comment.id => true })
  end

  it "should respect Topic::PRELOAD_COMMENTS_COUNT when loading initial comments" do
    stub_const(TopicView, "PRELOAD_COMMENTS_COUNT", 1) do
      topic_view = TopicView.new(topic, user)

      expect(topic_view.comments[answer.id].map(&:id)).to contain_exactly(comment.id)
      expect(topic_view.comments_counts[answer.id]).to eq(2)
    end
  end

  it "should preload the right comments even if comments have been deleted" do
    comment_4 = Fabricate(:post_voting_comment, post: answer)
    comment.trash!

    stub_const(TopicView, "PRELOAD_COMMENTS_COUNT", 2) do
      topic_view = TopicView.new(topic, user)

      expect(topic_view.comments[answer.id].map(&:id)).to contain_exactly(
        comment_2.id,
        comment_4.id,
      )
      expect(topic_view.comments_counts[answer.id]).to eq(2)
    end
  end

  describe "#filter_posts_near" do
    fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
    fab!(:post) { create_post(topic: topic) }

    fab!(:answer_plus_2_votes) do
      create_post(topic: topic).tap do |p|
        PostVoting::VoteManager.vote(p, Fabricate(:user), direction: PostVotingVote.directions[:up])
        PostVoting::VoteManager.vote(p, Fabricate(:user), direction: PostVotingVote.directions[:up])
      end
    end

    fab!(:answer_minus_2_votes) do
      create_post(topic: topic).tap do |p|
        PostVoting::VoteManager.vote(
          p,
          Fabricate(:user),
          direction: PostVotingVote.directions[:down],
        )
        PostVoting::VoteManager.vote(
          p,
          Fabricate(:user),
          direction: PostVotingVote.directions[:down],
        )
      end
    end

    fab!(:answer_minus_1_vote) do
      create_post(topic: topic).tap do |p|
        PostVoting::VoteManager.vote(
          p,
          Fabricate(:user),
          direction: PostVotingVote.directions[:down],
        )
      end
    end

    fab!(:answer_0_votes) { create_post(topic: topic) }

    fab!(:answer_plus_1_vote_deleted) do
      create_post(topic: topic).tap do |p|
        PostVoting::VoteManager.vote(p, Fabricate(:user), direction: PostVotingVote.directions[:up])
        p.trash!
      end
    end

    fab!(:answer_plus_1_vote) do
      create_post(topic: topic).tap do |p|
        PostVoting::VoteManager.vote(p, Fabricate(:user), direction: PostVotingVote.directions[:up])
      end
    end

    def topic_view_near(post)
      TopicView.new(topic.id, user, post_number: post.post_number)
    end

    before do
      Topic.reset_highest(topic.id)
      TopicView.stubs(:chunk_size).returns(3)
    end

    it "snaps to the lower boundary" do
      near_view = topic_view_near(post)
      expect(near_view.desired_post.id).to eq(post.id)
      expect(near_view.posts.map(&:id)).to eq(
        [post.id, answer_plus_2_votes.id, answer_plus_1_vote.id],
      )
    end

    it "snaps to the upper boundary" do
      near_view = topic_view_near(answer_minus_2_votes)

      expect(near_view.desired_post.id).to eq(answer_minus_2_votes.id)
      expect(near_view.posts.map(&:id)).to eq(
        [answer_0_votes.id, answer_minus_1_vote.id, answer_minus_2_votes.id],
      )
    end

    it "returns the posts in the middle" do
      near_view = topic_view_near(answer_0_votes)
      expect(near_view.desired_post.id).to eq(answer_0_votes.id)
      expect(near_view.posts.map(&:id)).to eq(
        [answer_plus_1_vote.id, answer_0_votes.id, answer_minus_1_vote.id],
      )
    end

    it "snaps to the lower boundary when deleted post_number is provided" do
      near_view =
        TopicView.new(
          topic.id,
          user,
          post_number: topic.posts.where("deleted_at IS NOT NULL").pick(:post_number),
        )

      expect(near_view.desired_post.id).to eq(post.id)
      expect(near_view.posts.map(&:id)).to eq(
        [post.id, answer_plus_2_votes.id, answer_plus_1_vote.id],
      )
    end

    it "snaps to the lower boundary when post_number is too large" do
      near_view = TopicView.new(topic.id, user, post_number: 99_999_999)

      expect(near_view.desired_post.id).to eq(post.id)
      expect(near_view.posts.map(&:id)).to eq(
        [post.id, answer_plus_2_votes.id, answer_plus_1_vote.id],
      )
    end

    it "returns the posts in the middle when sorted by activity" do
      near_view =
        TopicView.new(
          topic.id,
          user,
          post_number: answer_minus_1_vote.post_number,
          filter: TopicView::ACTIVITY_FILTER,
        )

      expect(near_view.desired_post.id).to eq(answer_minus_1_vote.id)
      expect(near_view.posts.map(&:id)).to eq(
        [answer_minus_2_votes.id, answer_minus_1_vote.id, answer_0_votes.id],
      )
    end
    describe "#next_page" do
      it "returns the next page properly when the highest id post is not the last" do
        expect(TopicView.new(topic.id, user, { post_number: post.post_number }).next_page).to eql(2)
      end
    end
  end

  describe "custom default scope filters" do
    fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
    fab!(:post_1) { create_post(topic: topic, raw: "kitties1", post_number: 1) }
    fab!(:post_2) { create_post(topic: topic, raw: "kitties2", post_number: 2) }

    fab!(:post_3) do
      create_post(topic: topic, raw: "poopy", post_number: 3, post_type: Post.types[:small_action])
    end

    fab!(:post_4) { create_post(topic: topic, raw: "kitties4", post_number: 4) }

    fab!(:post_5) do
      create_post(topic: topic, raw: "kitties5", post_number: 5, post_type: Post.types[:whisper])
    end

    fab!(:post_6) do
      create_post(
        topic: topic,
        raw: "kitties6",
        post_number: 6,
        post_type: Post.types[:moderator_action],
      )
    end

    before { SiteSetting.whispers_allowed_groups = "admins" }

    it "returns all posts in chronological order when filtered by ACTIVITY" do
      topic_view = TopicView.new(topic.id, admin, filter: TopicView::ACTIVITY_FILTER)

      expect(topic_view.posts.map(&:raw)).to eq(
        %w[kitties1 kitties2 poopy kitties4 kitties5 kitties6],
      )
    end

    it "returns posts that are not whispers or small action subtypes in chronological order when no filter" do
      topic_view = TopicView.new(topic.id, admin)

      expect(topic_view.posts.map(&:raw)).to eq(%w[kitties1 kitties2 kitties4 kitties6])
    end
  end
end
