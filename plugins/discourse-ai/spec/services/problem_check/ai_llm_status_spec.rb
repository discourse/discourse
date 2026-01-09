# frozen_string_literal: true

RSpec.describe ProblemCheck::AiLlmStatus do
  subject(:check) { described_class.new(target) }

  fab!(:llm_model)
  fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

  let(:target) { llm_model.id }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_persona = ai_persona.id
    SiteSetting.ai_summarization_enabled = true
  end

  def create_log(
    response_tokens:,
    response_status:,
    created_at: Time.zone.now,
    llm_id: llm_model.id
  )
    AiApiAuditLog.create!(
      provider_id: AiApiAuditLog::Provider::OpenAI,
      llm_id:,
      response_tokens:,
      response_status:,
      created_at:,
    )
  end

  describe ".fast_track_problem!" do
    it "does nothing for unsaved models" do
      unsaved = LlmModel.new(llm_model.attributes.except("id", "created_at", "updated_at"))

      expect { described_class.fast_track_problem!(unsaved, 5, 1) }.not_to raise_error
      expect(ProblemCheckTracker.where(identifier: "ai_llm_status").count).to eq(0)
    end
  end

  describe "#call" do
    it "does nothing if discourse-ai plugin disabled" do
      SiteSetting.discourse_ai_enabled = false
      expect(check).to be_chill_about_it
    end

    context "with plugin enabled" do
      before { enable_current_plugin }

      it "returns a problem when recent calls frequently fail" do
        3.times { create_log(response_tokens: 0, response_status: 500) }
        2.times { create_log(response_tokens: 15, response_status: 200) }

        expect(check).to have_a_problem.with_priority("high").with_target(llm_model.id)
      end

      it "no problem when failures below threshold" do
        2.times { create_log(response_tokens: 0, response_status: 500) }
        4.times { create_log(response_tokens: 10, response_status: 200) }

        expect(check).to be_chill_about_it
      end

      it "ignores stale failures outside lookback window" do
        3.times { create_log(response_tokens: 0, response_status: 500, created_at: 2.days.ago) }
        3.times { create_log(response_tokens: 12, response_status: 200) }

        expect(check).to be_chill_about_it
      end

      it "does not count zero-token 2xx as failures" do
        6.times { create_log(response_tokens: 0, response_status: 200) }

        expect(check).to be_chill_about_it
      end

      it "counts missing status with zero tokens as failures" do
        3.times { create_log(response_tokens: 0, response_status: nil) }
        3.times { create_log(response_tokens: 12, response_status: 200) }

        expect(check).to have_a_problem.with_target(llm_model.id)
      end

      it "skips seeded LLMs" do
        SiteSetting.ai_summarization_enabled = false
        seeded_llm = Fabricate(:seeded_model)
        SiteSetting.ai_summarization_persona =
          Fabricate(:ai_persona, default_llm_id: seeded_llm.id).id
        SiteSetting.ai_summarization_enabled = true

        3.times { create_log(response_tokens: 0, response_status: 500, llm_id: seeded_llm.id) }

        expect(described_class.new(seeded_llm.id)).to be_chill_about_it
      end
    end
  end
end
