# frozen_string_literal: true

RSpec.describe "reaction MessageBus audience" do
  fab!(:admin)
  fab!(:moderator)
  fab!(:other_moderator, :moderator)
  fab!(:non_staff_participant, :user)
  fab!(:topic, :topic_with_op)

  let(:topic_channel) { "/topic/#{topic.id}" }
  let(:reactions_channel) { "#{topic_channel}/reactions" }

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "clap|laughing"
    SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
  end

  def poll(channel, last_id = 0)
    post "/message-bus/#{SecureRandom.hex}/poll?dlp=t", params: { channel => last_id }
    expect(response.status).to eq(200)
    response.parsed_body.select { |message| message["channel"] == channel }
  end

  def reaction_payloads(messages, post)
    messages.filter_map { |message| message["data"] if message["data"]["post_id"] == post.id }
  end

  def acted_payloads(messages, post)
    messages.filter_map do |message|
      message["data"] if message["data"]["type"] == "acted" && message["data"]["id"] == post.id
    end
  end

  def toggle_reaction(post)
    sign_in(admin)
    put "/discourse-reactions/posts/#{post.id}/custom-reactions/clap/toggle.json"
    expect(response.status).to eq(200)
    reset!
  end

  it "withholds a whisper's reaction from readers who cannot see the whisper" do
    whisper = Fabricate(:whisper, topic: topic, user: moderator)
    toggle_reaction(whisper)

    get "/t/#{topic.id}.json"
    expect(response.parsed_body["post_stream"]["stream"]).not_to include(whisper.id)

    get "/posts/#{whisper.id}.json"
    expect(response.status).to eq(403)

    expect(acted_payloads(poll(topic_channel, 0), whisper)).to be_empty
    expect(reaction_payloads(poll(reactions_channel, 0), whisper)).to be_empty
  end

  it "delivers a whisper's reaction to staff who can see the whisper" do
    whisper = Fabricate(:whisper, topic: topic, user: moderator)
    toggle_reaction(whisper)

    sign_in(other_moderator)

    expect(reaction_payloads(poll(reactions_channel, 0), whisper)).to eq(
      [{ "post_id" => whisper.id, "reactions" => ["clap"] }],
    )
  end

  it "withholds a private-message whisper's reaction from non-staff participants" do
    private_message = Fabricate(:private_message_topic, user: moderator, recipient: admin)
    private_message.allowed_users << non_staff_participant
    whisper = Fabricate(:whisper, topic: private_message, user: moderator)
    toggle_reaction(whisper)

    sign_in(non_staff_participant)

    get "/posts/#{whisper.id}.json"
    expect(response.status).to eq(403)

    expect(acted_payloads(poll("/topic/#{private_message.id}", 0), whisper)).to be_empty
    expect(
      reaction_payloads(poll("/topic/#{private_message.id}/reactions", 0), whisper),
    ).to be_empty
  end

  it "still delivers a regular post's reaction to every topic reader" do
    regular_post = Fabricate(:post, topic: topic)
    toggle_reaction(regular_post)

    expect(reaction_payloads(poll(reactions_channel, 0), regular_post)).to eq(
      [{ "post_id" => regular_post.id, "reactions" => ["clap"] }],
    )
  end
end
