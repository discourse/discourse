# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor::ExecutionRateLimiter do
  fab!(:user)

  before { RateLimiter.enable }

  after { RateLimiter.disable }

  fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: user, published: true) }
  fab!(:other_workflow) do
    Fabricate(:discourse_workflows_workflow, created_by: user, published: true)
  end

  let(:limiter) { described_class.new(workflow) }

  describe "#within_limits?" do
    it "returns true when under limits" do
      SiteSetting.discourse_workflows_max_executions_per_minute = 10
      SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 5

      expect(limiter.within_limits?).to be(true)
    end

    it "returns false when per-workflow limit is exceeded" do
      SiteSetting.discourse_workflows_max_executions_per_minute = 100
      SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1

      expect(limiter.within_limits?).to be(true)
      expect(limiter.within_limits?).to be(false)
    end

    it "returns false when global limit is exceeded" do
      SiteSetting.discourse_workflows_max_executions_per_minute = 1
      SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 100

      expect(limiter.within_limits?).to be(true)
      expect(limiter.within_limits?).to be(false)
    end

    it "tracks limits independently per workflow" do
      SiteSetting.discourse_workflows_max_executions_per_minute = 100
      SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1

      other_limiter = described_class.new(other_workflow)

      expect(limiter.within_limits?).to be(true)
      expect(limiter.within_limits?).to be(false)
      expect(other_limiter.within_limits?).to be(true)
    end
  end
end
