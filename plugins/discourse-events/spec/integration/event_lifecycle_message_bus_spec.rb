# frozen_string_literal: true

require_relative "../../jobs/regular/discourse_post_event/event_started"

RSpec.describe "event lifecycle message bus security" do
  fab!(:group)
  fab!(:member, :user)
  fab!(:private_category) { Fabricate(:private_category, group:) }
  fab!(:topic) { Fabricate(:topic, category: private_category) }
  fab!(:event_post) { Fabricate(:post, topic:) }
  fab!(:event) do
    Fabricate(
      :event,
      post: event_post,
      original_starts_at: 7.days.after,
      original_ends_at: 7.days.after + 1.hour,
    )
  end

  before { group.add(member) }

  it "does not expose private event completion reloads to anonymous MessageBus clients",
     :aggregate_failures do
    channel = "/topic/#{topic.id}"
    message_id = MessageBus.last_id(channel)

    freeze_time(8.days.after) { Jobs::DiscourseCalendar::MonitorEventDates.new.execute({}) }

    poll(channel, message_id)
    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to be_empty

    sign_in(member)
    poll(channel, message_id)
    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to contain_exactly(
      include("data" => { "reload_topic" => true, "refresh_stream" => true }),
    )
  end

  it "does not expose private event start reloads to anonymous MessageBus clients",
     :aggregate_failures do
    channel = "/topic/#{topic.id}"
    message_id = MessageBus.last_id(channel)

    Jobs::DiscoursePostEventEventStarted.new.execute(event_id: event.id)

    poll(channel, message_id)
    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to be_empty

    sign_in(member)
    poll(channel, message_id)
    expect(response.status).to eq(200)
    expect(topic_reload_messages(channel)).to contain_exactly(
      include("data" => { "reload_topic" => true, "refresh_stream" => true }),
    )
  end

  def poll(channel, message_id)
    post "/message-bus/poll?dlp=t", params: { channel => message_id }
  end

  def topic_reload_messages(channel)
    response.parsed_body.select do |message|
      message["channel"] == channel &&
        message["data"] == { "reload_topic" => true, "refresh_stream" => true }
    end
  end
end
