# frozen_string_literal: true

RSpec.describe "Livestream channel list serialization" do
  fab!(:user)
  fab!(:category)
  fab!(:group) { Fabricate(:group).tap { |g| g.add(user) } }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    # avoid the onebox-warming job making a real request
    Jobs.run_later!
    sign_in(user)
  end

  def create_livestream_channel
    topic = Fabricate(:topic, category:)
    post = Fabricate(:post, topic:)
    DiscoursePostEvent::Event.create!(
      id: post.id,
      original_starts_at: 1.hour.from_now,
      original_ends_at: 2.hours.from_now,
      location: "https://example.com/live",
      status: DiscoursePostEvent::Event.statuses[:private],
      raw_invitees: [group.name],
      livestream: true,
    )
    topic.reload.topic_chat_channel.chat_channel
  end

  def event_related_query_count(queries)
    queries.count do |sql|
      sql.include?("discourse_post_event_invitees") || sql.include?("discourse_post_event_events")
    end
  end

  it "batches livestream metadata instead of querying per channel" do
    create_livestream_channel

    queries_for_one = track_sql_queries { get "/chat/api/channels.json", params: { filter: "" } }
    expect(response.status).to eq(200)
    channels = response.parsed_body["channels"]
    expect(channels.filter_map { |c| c["livestream_topic"] }).to be_present

    create_livestream_channel
    create_livestream_channel

    queries_for_many = track_sql_queries { get "/chat/api/channels.json", params: { filter: "" } }
    expect(response.status).to eq(200)
    expect(response.parsed_body["channels"].size).to be >= 3

    expect(event_related_query_count(queries_for_many)).to eq(
      event_related_query_count(queries_for_one),
    )
  end
end
