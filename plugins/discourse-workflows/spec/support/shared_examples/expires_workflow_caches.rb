# frozen_string_literal: true

RSpec.shared_examples "expires workflow caches" do
  it "expires workflow caches" do
    DiscourseWorkflows::Workflow::Action::ExpireCaches.expects(:call).once
    result
  end
end
