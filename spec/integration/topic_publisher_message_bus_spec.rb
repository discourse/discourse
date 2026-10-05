# frozen_string_literal: true

RSpec.describe "topic publisher message bus security" do
  fab!(:moderator)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:shared_drafts_category, :category)
  fab!(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }
  fab!(:opening_post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.shared_drafts_category = shared_drafts_category.id
    group.add(moderator)
  end

  it "does not expose publishing to a restricted category to anonymous MessageBus clients" do
    channel = "/topic/#{topic.id}"
    message_id = MessageBus.last_id(channel)

    sign_in(moderator)
    messages =
      MessageBus.track_publish do
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: private_category.id }
      end

    expect(response.status).to eq(200)
    expect(topic.reload.secure_audience_publish_messages[:group_ids]).to contain_exactly(group.id)
    expect(
      messages
        .find { |message| message.data == { reload_topic: true, refresh_stream: true } }
        .group_ids,
    ).to contain_exactly(group.id)

    cookies.to_hash.keys.each { |key| cookies.delete(key) }

    post "/message-bus/poll?dlp=t", params: { channel => message_id }

    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to be_empty

    sign_in(moderator)
    post "/message-bus/poll?dlp=t", params: { channel => message_id }

    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to contain_exactly(
      include("data" => include("reload_topic" => true, "refresh_stream" => true)),
    )
  end

  def topic_reload_messages(channel)
    response.parsed_body.select do |message|
      message["channel"] == channel &&
        message["data"] == { "reload_topic" => true, "refresh_stream" => true }
    end
  end
end
