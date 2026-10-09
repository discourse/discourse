# frozen_string_literal: true

RSpec.describe "event date monitoring MessageBus security" do
  fab!(:member, :user)
  fab!(:group)
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:restricted_topic) { Fabricate(:topic, category: private_category) }
  fab!(:restricted_post) { Fabricate(:post, topic: restricted_topic) }
  fab!(:restricted_event) do
    Fabricate(
      :event,
      post: restricted_post,
      original_starts_at: 7.days.after,
      original_ends_at: 7.days.after + 1.hour,
    )
  end
  fab!(:private_message_recipient, :user)
  fab!(:private_message_topic) do
    Fabricate(:private_message_topic, recipient: private_message_recipient)
  end
  fab!(:private_message_post) { Fabricate(:post, topic: private_message_topic) }
  fab!(:private_message_event) do
    Fabricate(
      :event,
      post: private_message_post,
      original_starts_at: 7.days.after,
      original_ends_at: 7.days.after + 1.hour,
    )
  end

  before do
    SiteSetting.discourse_post_event_enabled = true
    group.add(member)
  end

  it "does not expose a restricted topic's event completion to anonymous MessageBus clients" do
    channel = "/topic/#{restricted_topic.id}"
    message_id = MessageBus.last_id(channel)

    freeze_time 8.days.after
    Jobs::DiscourseCalendar::MonitorEventDates.new.execute({})

    post "/message-bus/poll?dlp=t", params: { channel => message_id }

    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to be_empty

    sign_in(member)
    post "/message-bus/poll?dlp=t", params: { channel => message_id }

    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to contain_exactly(
      include("data" => include("reload_topic" => true, "refresh_stream" => true)),
    )
  end

  it "delivers a private message event completion only to its recipients" do
    channel = "/topic/#{private_message_topic.id}"
    message_id = MessageBus.last_id(channel)

    freeze_time 8.days.after
    Jobs::DiscourseCalendar::MonitorEventDates.new.execute({})

    post "/message-bus/poll?dlp=t", params: { channel => message_id }

    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to be_empty

    sign_in(private_message_recipient)
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
