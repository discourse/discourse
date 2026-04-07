# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ExecutionSession do
  it "defines the session interface methods" do
    methods = described_class.instance_methods(false)
    expect(methods).to include(
      :next_step_position,
      :store_context,
      :resolver_context,
      :node_context_for,
      :enqueue,
      :shift_queue,
      :queued?,
      :record_step,
      :mark_wait,
    )
  end

  it "is included in ExecutionState" do
    expect(DiscourseWorkflows::Executor::ExecutionState.ancestors).to include(described_class)
  end
end
