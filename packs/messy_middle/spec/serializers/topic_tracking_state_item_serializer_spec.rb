# frozen_string_literal: true

RSpec.describe TopicTrackingStateItemSerializer do
  fab!(:user) { Fabricate(:user) }
  fab!(:post) { create_post }

  before do
    SiteSetting.navigation_menu = "legacy"
    SiteSetting.chat_enabled = false if defined?(::Chat)
  end

  it "serializes topic tracking state reports" do
    report = TopicTrackingState.report(user)
    serialized = described_class.new(report[0], scope: Guardian.new(user), root: false).as_json

    expect(serialized[:topic_id]).to eq(post.topic_id)
    expect(serialized[:highest_post_number]).to eq(post.topic.highest_post_number)
    expect(serialized[:last_read_post_number]).to eq(nil)
    expect(serialized[:created_at]).to be_present
    expect(serialized[:notification_level]).to eq(nil)
    expect(serialized[:created_in_new_period]).to eq(true)
    expect(serialized[:treat_as_new_topic_start_date]).to be_present
    expect(serialized.has_key?(:tags)).to eq(false)
  end

  it "includes tags attribute when tags are present" do
    TopicTrackingState.include_tags_in_report = true

    post.topic.notifier.watch_topic!(post.topic.user_id)

    DiscourseTagging.tag_topic_by_names(
      post.topic,
      Guardian.new(Discourse.system_user),
      %w[bananas apples],
    )

    report = TopicTrackingState.report(user)
    serialized = described_class.new(report[0], scope: Guardian.new(user), root: false).as_json

    expect(serialized[:tags]).to contain_exactly("bananas", "apples")
  ensure
    TopicTrackingState.include_tags_in_report = false
  end
end
