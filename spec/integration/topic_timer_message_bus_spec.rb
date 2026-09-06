# frozen_string_literal: true

RSpec.describe "topic timer message bus security" do
  fab!(:admin)
  fab!(:group)
  fab!(:member, :user)
  fab!(:group_user) { Fabricate(:group_user, group: group, user: member) }
  fab!(:private_category) { Fabricate(:private_category, group: group) }
  fab!(:topic) { Fabricate(:topic, category: private_category) }

  it "does not expose restricted timer reloads", :aggregate_failures do
    channel = "/topic/#{topic.id}"

    close_timer =
      Fabricate(
        :topic_timer,
        user: admin,
        topic: topic,
        execute_at: 1.minute.ago,
        created_at: 2.minutes.ago,
      )
    close_last_id = MessageBus.last_id(channel)

    Jobs::CloseTopic.new.execute(topic_timer_id: close_timer.id)

    post "/message-bus/poll?dlp=t", params: { channel => close_last_id }
    expect(response.status).to eq(200)
    expect(reload_topic_messages(channel)).to be_empty

    open_timer =
      Fabricate(
        :topic_timer,
        status_type: TopicTimer.types[:open],
        user: admin,
        topic: topic,
        execute_at: 1.minute.ago,
        created_at: 2.minutes.ago,
      )
    open_last_id = MessageBus.last_id(channel)

    Jobs::OpenTopic.new.execute(topic_timer_id: open_timer.id)

    post "/message-bus/poll?dlp=t", params: { channel => open_last_id }
    expect(response.status).to eq(200)
    expect(reload_topic_messages(channel)).to be_empty

    sign_in(member)
    post "/message-bus/poll?dlp=t", params: { channel => open_last_id }
    expect(response.status).to eq(200)
    expect(reload_topic_messages(channel)).to be_present
  end

  def reload_topic_messages(channel)
    response.parsed_body.select do |message|
      data = message["data"]
      message["channel"] == channel && data.is_a?(Hash) && data["reload_topic"] == true
    end
  end
end
