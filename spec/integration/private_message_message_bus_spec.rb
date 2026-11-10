# frozen_string_literal: true

RSpec.describe "private message MessageBus audiences" do
  fab!(:moderator)
  fab!(:staff_participant, :moderator)
  fab!(:admin)
  fab!(:group)
  fab!(:group_member, :user)
  fab!(:topic) { Fabricate(:private_message_topic, allowed_groups: [group]) }
  fab!(:private_post) { Fabricate(:post, topic: topic, user: topic.user) }

  let(:channel) { "/topic/#{topic.id}" }

  before do
    group.add(group_member)
    topic.allowed_users << staff_participant
  end

  it "delivers PM activity to everyone who can see the PM" do
    message_id = publish_activity(private_post)

    [topic.user, group_member, staff_participant, admin].each do |viewer|
      expect(created_messages(viewer, message_id)).to include(
        include("user_id" => private_post.user_id, "username" => topic.user.username),
      )
    end
  end

  it "hides PM activity from moderators who cannot see the PM" do
    message_id = publish_activity(private_post)

    sign_in(moderator)
    get "/t/#{topic.id}.json"
    expect(response.status).to eq(404)

    expect(channel_messages(moderator, message_id)).to be_empty
  end

  it "restricts PM whispers to staff who can see the PM" do
    whisper = Fabricate(:whisper, topic: topic, user: staff_participant)
    message_id = publish_activity(whisper)

    [staff_participant, admin].each do |viewer|
      expect(created_messages(viewer, message_id)).to include(
        include("user_id" => whisper.user_id, "username" => staff_participant.username),
      )
    end

    # Ordinary participants still receive the topic stats message, never the whisper.
    expect(created_messages(group_member, message_id)).to be_empty
    expect(channel_messages(moderator, message_id)).to be_empty
  end

  def publish_activity(target_post)
    message_id = MessageBus.last_id(channel)
    target_post.publish_change_to_clients!(:created)
    message_id
  end

  def channel_messages(viewer, message_id)
    sign_in(viewer)
    post "/message-bus/poll?dlp=t", params: { channel => message_id }
    expect(response.status).to eq(200)
    response.parsed_body.select { |message| message["channel"] == channel }
  end

  def created_messages(viewer, message_id)
    channel_messages(viewer, message_id).filter_map do |message|
      message["data"] if message["data"]["type"] == "created"
    end
  end
end
