# frozen_string_literal: true

RSpec.describe "DiscoursePoll hidden post serialization" do
  fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:voter) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:topic)
  fab!(:first_post) { Fabricate(:post, topic:) }
  fab!(:poll_post) { Fabricate(:post, user: author, topic:, raw: <<~RAW) }
      [poll public=true]
      - Secret option A
      - Secret option B
      [/poll]
    RAW

  before do
    DiscoursePoll::Poll.vote(
      voter,
      poll_post.id,
      DiscoursePoll::DEFAULT_POLL_NAME,
      [poll_post.polls.first.poll_options.first.digest],
    )
    poll_post.hide!(PostActionType.types[:inappropriate])
  end

  def serialized_poll_post
    get "/t/#{topic.id}.json"

    expect(response.status).to eq(200)

    response.parsed_body["post_stream"]["posts"].find { |p| p["id"] == poll_post.id }
  end

  it "omits polls of hidden posts for viewers who cannot see hidden posts" do
    serialized = serialized_poll_post

    expect(serialized).not_to have_key("polls")
    expect(response.body).not_to include("Secret option A")
    expect(response.body).not_to include(voter.username)
  end

  it "omits the viewer's own votes on hidden posts" do
    sign_in(voter)

    serialized = serialized_poll_post

    expect(serialized).not_to have_key("polls")
    expect(serialized).not_to have_key("polls_votes")
  end

  it "keeps polls visible to staff" do
    sign_in(admin)

    serialized = serialized_poll_post

    expect(serialized["polls"].first["options"].map { |o| o["html"] }).to include("Secret option A")
  end

  it "keeps polls visible to the hidden post's author" do
    sign_in(author)

    expect(serialized_poll_post).to have_key("polls")
  end
end
