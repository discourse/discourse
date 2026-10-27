# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ComposerTarget do
  def exec_ctx(trigger_data)
    DiscourseWorkflows::Executor::NodeExecutionContext.new(
      input_items: [{ "json" => {} }],
      flow_context: {
        "$trigger" => trigger_data,
      },
    )
  end

  it "reads the draft key from the trigger, not the current items" do
    expect(described_class.from(exec_ctx({ "composer" => { "draft_key" => "topic_12" } }))).to eq(
      draft_key: "topic_12",
    )
  end

  it "reads the requested item of a multi-item trigger" do
    trigger_data = [
      { "composer" => { "draft_key" => "new_topic" } },
      { "composer" => { "draft_key" => "topic_12" } },
    ]

    expect(described_class.from(exec_ctx(trigger_data), 1)).to eq(draft_key: "topic_12")
  end

  it "returns nil when another trigger started the workflow" do
    expect(described_class.from(exec_ctx({ "post" => { "id" => 1 } }))).to be_nil
    expect(described_class.from(exec_ctx(nil))).to be_nil
  end
end
