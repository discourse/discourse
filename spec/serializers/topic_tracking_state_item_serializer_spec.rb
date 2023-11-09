# frozen_string_literal: true

RSpec.describe TopicTrackingStateItemSerializer do
  fab!(:user)
  fab!(:post) { create_post }

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
  end

  it "includes tags attribute when `tagging_enabled` site setting is `true`" do
    SiteSetting.tagging_enabled = true

    post.topic.notifier.watch_topic!(post.topic.user_id)

    DiscourseTagging.tag_topic_by_names(
      post.topic,
      Guardian.new(Discourse.system_user),
      %w[bananas apples],
    )

    report = TopicTrackingState.report(user)
    serialized = described_class.new(report[0], scope: Guardian.new(user), root: false).as_json

    expect(serialized[:tags]).to contain_exactly("bananas", "apples")
  end
end
