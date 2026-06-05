# frozen_string_literal: true

RSpec.describe "DiscoursePoll ranked choice result visibility" do
  fab!(:voter) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:non_voter) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:author, :admin)

  def create_ranked_choice_post(results:)
    topic = Fabricate(:topic, user: author)

    Fabricate(:post, user: author, topic: topic, raw: <<~RAW)
      [poll type=ranked_choice results=#{results}]
      - Red
      - Blue
      - Yellow
      [/poll]
    RAW
  end

  def ranked_choice_vote_options(poll)
    {
      "0" => {
        digest: poll.poll_options.first.digest,
        rank: "1",
      },
      "1" => {
        digest: poll.poll_options.second.digest,
        rank: "2",
      },
      "2" => {
        digest: poll.poll_options.third.digest,
        rank: "0",
      },
    }
  end

  def vote_in_ranked_choice_poll(user, post)
    DiscoursePoll::Poll.vote(
      user,
      post.id,
      DiscoursePoll::DEFAULT_POLL_NAME,
      ranked_choice_vote_options(post.polls.first),
    )
  end

  def topic_view_poll(post)
    get "/t/#{post.topic.slug}/#{post.topic.id}.json"

    expect(response.status).to eq(200)

    response.parsed_body["post_stream"]["posts"]
      .find { |serialized_post| serialized_post["id"] == post.id }
      .fetch("polls")
      .first
  end

  it "omits the outcome from vote responses when staff-only results are hidden from the voter" do
    post = create_ranked_choice_post(results: "staff_only")

    sign_in(voter)
    put "/polls/vote.json",
        params: {
          post_id: post.id,
          poll_name: DiscoursePoll::DEFAULT_POLL_NAME,
          options: ranked_choice_vote_options(post.polls.first),
        }

    expect(response.status).to eq(200)
    expect(response.parsed_body["poll"]).not_to have_key("ranked_choice_outcome")

    delete "/polls/vote.json",
           params: {
             post_id: post.id,
             poll_name: DiscoursePoll::DEFAULT_POLL_NAME,
           }

    expect(response.status).to eq(200)
    expect(response.parsed_body["poll"]).not_to have_key("ranked_choice_outcome")
  end

  it "keeps a staff-visible outcome out of shared vote broadcasts" do
    post = create_ranked_choice_post(results: "staff_only")

    sign_in(author)
    messages =
      MessageBus.track_publish("/polls/#{post.topic.id}") do
        put "/polls/vote.json",
            params: {
              post_id: post.id,
              poll_name: DiscoursePoll::DEFAULT_POLL_NAME,
              options: ranked_choice_vote_options(post.polls.first),
            }
      end

    expect(response.status).to eq(200)
    expect(response.parsed_body["poll"]).to have_key("ranked_choice_outcome")
    expect(messages.size).to eq(1)

    published_poll = messages.first.data.deep_stringify_keys["polls"].first
    expect(published_poll).not_to have_key("ranked_choice_outcome")
  end

  it "shows on-vote outcomes to voters without leaking them to non-voters" do
    post = create_ranked_choice_post(results: "on_vote")

    sign_in(voter)
    messages =
      MessageBus.track_publish("/polls/#{post.topic.id}") do
        put "/polls/vote.json",
            params: {
              post_id: post.id,
              poll_name: DiscoursePoll::DEFAULT_POLL_NAME,
              options: ranked_choice_vote_options(post.polls.first),
            }
      end

    expect(response.status).to eq(200)
    expect(response.parsed_body["poll"]).to have_key("ranked_choice_outcome")
    expect(messages.size).to eq(1)

    published_poll = messages.first.data.deep_stringify_keys["polls"].first
    expect(published_poll).not_to have_key("ranked_choice_outcome")

    sign_in(non_voter)
    expect(topic_view_poll(post)).not_to have_key("ranked_choice_outcome")

    sign_in(voter)
    expect(topic_view_poll(post)).to have_key("ranked_choice_outcome")
  end

  it "omits on-close outcomes from anonymous topic views while the poll is open" do
    post = create_ranked_choice_post(results: "on_close")

    vote_in_ranked_choice_poll(voter, post)

    expect(topic_view_poll(post)).not_to have_key("ranked_choice_outcome")
  end
end
