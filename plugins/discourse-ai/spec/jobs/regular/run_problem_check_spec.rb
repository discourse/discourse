# frozen_string_literal: true

RSpec.describe Jobs::RunProblemCheck do
  subject(:run_check_job) { described_class.new }

  describe "integration specs for AI-based problem checks" do
    before { enable_current_plugin }

    context "when running AI LLM status checks" do
      let(:identifier) { :ai_llm_status }

      let!(:llm_model) { assign_fake_provider_to(:ai_default_llm_model) }

      before { SiteSetting.ai_summarization_enabled = true }

      context "when everything is OK" do
        it "creates a problem check tracker that is targeting the tested model" do
          DiscourseAi::Completions::Llm.with_prepared_responses(["OK"]) do
            run_check_job.execute(check_identifier: identifier)
          end

          created_trackers = ProblemCheckTracker.where(identifier: identifier)

          expect(created_trackers.size).to eq(1)
          expect(created_trackers.last.target).to eq(llm_model.id.to_s)
        end
      end
    end

    context "when running AI Credit soft limits checks" do
      let(:identifier) { :ai_credit_soft_limit }

      fab!(:llm_model) { Fabricate(:llm_model, id: -1) }

      context "when we haven't reach the soft limit yet" do
        it "creates a problem check tracker that is targeting the tested model" do
          Fabricate(
            :llm_credit_allocation,
            llm_model: llm_model,
            monthly_credits: 1000,
            monthly_used: 700,
            soft_limit_percentage: 80,
          )

          run_check_job.execute(check_identifier: identifier)

          created_trackers = ProblemCheckTracker.where(identifier: identifier)

          expect(created_trackers.size).to eq(1)
          expect(created_trackers.last.target).to eq(llm_model.id.to_s)
        end
      end
    end

    context "when running AI Credit hard limits checks" do
      let(:identifier) { :ai_credit_hard_limit }

      fab!(:llm_model) { Fabricate(:llm_model, id: -1) }

      context "when we haven't reach the soft limit yet" do
        it "creates a problem check tracker that is targeting the tested model" do
          Fabricate(
            :llm_credit_allocation,
            llm_model: llm_model,
            monthly_credits: 1000,
            monthly_used: 850,
            soft_limit_percentage: 80,
          )

          run_check_job.execute(check_identifier: identifier)

          created_trackers = ProblemCheckTracker.where(identifier: identifier)

          expect(created_trackers.size).to eq(1)
          expect(created_trackers.last.target).to eq(llm_model.id.to_s)
        end
      end
    end
  end
end
