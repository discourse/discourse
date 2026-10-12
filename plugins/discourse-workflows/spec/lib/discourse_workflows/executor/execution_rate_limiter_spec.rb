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

  describe "#exceeded_limit_message" do
    it "explains when the per-workflow limit is exceeded" do
      SiteSetting.discourse_workflows_max_executions_per_minute = 100
      SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 2

      2.times { expect(limiter.exceeded_limit_message).to be_nil }

      expect(limiter.exceeded_limit_message).to eq(
        I18n.t("discourse_workflows.errors.rate_limited.per_workflow", count: 2),
      )
    end

    it "explains when the global limit is exceeded" do
      SiteSetting.discourse_workflows_max_executions_per_minute = 2
      SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 100

      2.times { expect(limiter.exceeded_limit_message).to be_nil }

      expect(limiter.exceeded_limit_message).to eq(
        I18n.t("discourse_workflows.errors.rate_limited.global", count: 2),
      )
    end

    it "tracks limits independently per workflow" do
      SiteSetting.discourse_workflows_max_executions_per_minute = 100
      SiteSetting.discourse_workflows_max_executions_per_minute_per_workflow = 1

      other_limiter = described_class.new(other_workflow)

      expect(limiter.exceeded_limit_message).to be_nil
      expect(limiter.exceeded_limit_message).to be_present
      expect(other_limiter.exceeded_limit_message).to be_nil
    end
  end
end
