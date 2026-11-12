# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Workflow::Action::ExpireCaches do
  describe ".call" do
    subject(:result) { described_class.call }

    it "clears workflow dependency caches" do
      DiscourseWorkflows::WorkflowDependency.expects(:clear_cache!).once

      result
    end

    it "does not clear the site cache" do
      Site.expects(:clear_cache).never
      DiscourseWorkflows::WorkflowDependency.stubs(:clear_cache!)

      result
    end
  end
end
