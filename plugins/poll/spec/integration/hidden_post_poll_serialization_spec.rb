# frozen_string_literal: true

RSpec.describe "DiscoursePoll hidden post serialization", type: :request do
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

  it "keeps polls and the viewer's votes visible on ordinary posts" do
    poll_post.unhide!
    sign_in(voter)

    serialized = serialized_poll_post

    expect(serialized["polls"].first["options"].map { |o| o["html"] }).to include("Secret option A")
    expect(serialized["polls_votes"]["poll"]).to contain_exactly(
      poll_post.polls.first.poll_options.first.digest,
    )
  end

  it "keeps hidden polls and votes visible to members of allowed groups" do
    group = Fabricate(:group)
    group.add(voter)
    SiteSetting.hidden_post_visible_groups = group.id.to_s
    sign_in(voter)

    serialized = serialized_poll_post

    expect(serialized["polls"].first["options"].map { |o| o["html"] }).to include("Secret option A")
    expect(serialized["polls_votes"]["poll"]).to contain_exactly(
      poll_post.polls.first.poll_options.first.digest,
    )
  end

  it "keeps polls visible to staff" do
    sign_in(admin)

    serialized = serialized_poll_post

    expect(serialized["polls"].first["options"].map { |o| o["html"] }).to include("Secret option A")
  end

  describe "poll refresh through the post endpoint" do
    it "returns current poll data for a visible post" do
      poll_post.unhide!
      get "/posts/#{poll_post.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["polls"].first["options"].map { |o| o["html"] }).to include(
        "Secret option A",
      )
    end

    it "preserves refresh access for the hidden post's author" do
      sign_in(author)
      get "/posts/#{poll_post.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["polls"]).to be_present
    end

    it "denies refresh access for viewers who cannot see the hidden post" do
      get "/posts/#{poll_post.id}.json"

      expect(response.status).to eq(404)
    end
  end

  describe "poll mutation rate limits" do
    before do
      poll_post.unhide!
      sign_in(author)
      RateLimiter.enable
      20.times { RateLimiter.new(author, "poll-mutations", 20, 1.minute).performed! }
    end

    it "rate limits votes" do
      put "/polls/vote.json",
          params: {
            post_id: poll_post.id,
            poll_name: "poll",
            options: [poll_post.polls.first.poll_options.first.digest],
          }

      expect(response.status).to eq(429)
    end

    it "shares the limit with vote removals" do
      delete "/polls/vote.json", params: { post_id: poll_post.id, poll_name: "poll" }

      expect(response.status).to eq(429)
    end

    it "shares the limit with status changes" do
      put "/polls/toggle_status.json",
          params: {
            post_id: poll_post.id,
            poll_name: "poll",
            status: "closed",
          }

      expect(response.status).to eq(429)
    end

    it "allows mutations again after the rate-limit window" do
      freeze_time 1.minute.from_now + 1.second

      delete "/polls/vote.json", params: { post_id: poll_post.id, poll_name: "poll" }

      expect(response.status).to eq(200)
    end
  end

  describe "poll broadcasts" do
    def poll_messages(&block)
      MessageBus.track_publish("/polls/#{topic.id}", &block)
    end

    it "does not broadcast hidden poll status changes, but returns the poll to its author" do
      sign_in(author)

      messages =
        poll_messages do
          put "/polls/toggle_status.json",
              params: {
                post_id: poll_post.id,
                poll_name: "poll",
                status: "closed",
              }
        end

      expect(response.status).to eq(200)
      expect(response.parsed_body["poll"]["status"]).to eq("closed")
      expect(messages).to be_empty
    end

    it "does not broadcast votes or vote removals on hidden polls" do
      sign_in(author)

      messages =
        poll_messages do
          put "/polls/vote.json",
              params: {
                post_id: poll_post.id,
                poll_name: "poll",
                options: [poll_post.polls.first.poll_options.first.digest],
              }
        end

      expect(response.status).to eq(200)
      expect(messages).to be_empty

      messages =
        poll_messages do
          delete "/polls/vote.json", params: { post_id: poll_post.id, poll_name: "poll" }
        end

      expect(response.status).to eq(200)
      expect(messages).to be_empty
    end

    it "does not broadcast hidden polls from the updater or post-created hook" do
      expect(poll_messages { DiscoursePoll::PollsUpdater.publish_changes(poll_post) }).to be_empty
      expect(
        poll_messages { DiscourseEvent.trigger(:post_created, poll_post, {}, author) },
      ).to be_empty
    end

    it "resumes broadcasts when a post is no longer hidden" do
      poll_post.unhide!

      messages = poll_messages { DiscoursePoll::PollsUpdater.publish_changes(poll_post) }

      expect(messages.size).to eq(1)
      expect(messages.first.data).to eq(post_id: poll_post.id)
    end
  end

  it "keeps polls visible to the hidden post's author" do
    sign_in(author)

    expect(serialized_poll_post).to have_key("polls")
  end
end
