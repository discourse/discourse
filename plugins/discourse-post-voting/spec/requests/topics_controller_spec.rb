# frozen_string_literal: true

describe TopicsController do
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:post) { create_post(topic: topic) }
  fab!(:comment) { Fabricate(:post_voting_comment, raw: "this is a comment!", post: post) }

  fab!(:answer) { create_post(topic: topic) }
  fab!(:answer_2) { create_post(topic: topic) }
  fab!(:answer_3) { create_post(topic: topic) }

  fab!(:vote) do
    PostVoting::VoteManager.vote(answer_2, user, direction: PostVotingVote.directions[:up])
  end

  fab!(:vote_2) do
    PostVoting::VoteManager.vote(answer, user, direction: PostVotingVote.directions[:down])
  end

  before { SiteSetting.post_voting_enabled = true }

  describe "#show" do
    it "orders posts by number of votes for a Post Voting topic" do
      get "/t/#{topic.id}.json"

      expect(response.status).to eq(200)

      payload = response.parsed_body

      expect(payload["post_stream"]["posts"].map { |p| p["id"] }).to eq(
        [post.id, answer_2.id, answer_3.id, answer.id],
      )
    end

    it "does not error for topic views without any posts" do
      get "/t/#{topic.id}.json?page=2"

      expect(response.status).to eq(404)
    end

    it "orders posts by date of creation when 'activity' filter is provided" do
      get "/t/#{topic.id}.json?filter=#{TopicView::ACTIVITY_FILTER}"

      expect(response.status).to eq(200)

      payload = response.parsed_body

      expect(payload["post_stream"]["posts"].map { |p| p["id"] }).to eq(
        [post.id, answer.id, answer_2.id, answer_3.id],
      )
    end

    it "includes post_voting comments in crawler view" do
      get "/t/#{topic.slug}/#{topic.id}", env: { "HTTP_USER_AGENT" => "Googlebot" }

      expect(response.status).to eq(200)
      expect(response.body).to match(
        %r{<span class="post-voting-comments__comment-cooked" itemprop="text"><p>this is a comment!</p></span>},
      )
      expect(response.body).to match(%r{<span class="post-voting-answer-count__value">3</span>})
    end
  end
end
