# frozen_string_literal: true

RSpec.describe "nested_replies tasks" do
  it "enables maintenance and enqueues site-wide stats preparation" do
    Fabricate(:topic)
    max_topic_id = Topic.where(archetype: Archetype.default, deleted_at: nil).maximum(:id)
    SiteSetting.nested_replies_stats_maintenance_enabled = false

    output = capture_stdout { invoke_rake_task("nested_replies:prepare_stats") }

    expect(SiteSetting.nested_replies_stats_maintenance_enabled).to eq(true)
    expect(Jobs::PrepareNestedReplyStats.jobs.size).to eq(1)
    args = Jobs::PrepareNestedReplyStats.jobs.first["args"].first.with_indifferent_access
    expect(args).to include(max_topic_id: max_topic_id)
    expect(output).to include("Enqueued nested reply stats preparation")
  end
end
