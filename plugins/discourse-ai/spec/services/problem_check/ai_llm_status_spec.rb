# frozen_string_literal: true

RSpec.describe ProblemCheck::AiLlmStatus do
  subject(:check) { described_class.new(target) }

  fab!(:llm_model)
  fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

  let(:target) { llm_model.id }
  let(:provider) { AiApiAuditLog::Provider::OpenAI }

  before do
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_persona = ai_persona.id
    SiteSetting.ai_summarization_enabled = true
  end

  describe "#call" do
    it "does nothing if discourse-ai plugin disabled" do
      SiteSetting.discourse_ai_enabled = false
      expect(check).to be_chill_about_it
    end

    context "with discourse-ai plugin enabled for the site" do
      before { enable_current_plugin }

      it "returns a problem when recent calls frequently fail" do
        3.times { create_log(response_tokens: 0, response_status: 500) }
        2.times { create_log(response_tokens: 15, response_status: 200) }

        message =
          I18n.t(
            "dashboard.problem.ai_llm_status",
            {
              model_name: llm_model.display_name,
              url: "/admin/plugins/discourse-ai/ai-llms/#{llm_model.id}/edit",
            },
          )

        expect(check).to have_a_problem
          .with_priority("high")
          .with_target(llm_model.id)
          .with_message(message)
      end

      it "does not return a problem when failures are below the threshold" do
        2.times { create_log(response_tokens: 0, response_status: 500) }
        4.times { create_log(response_tokens: 10, response_status: 200) }

        expect(check).to be_chill_about_it
      end

      it "ignores stale failures outside the lookback window" do
        3.times { create_log(response_tokens: 0, response_status: 500, created_at: 2.days.ago) }
        3.times { create_log(response_tokens: 12, response_status: 200) }

        expect(check).to be_chill_about_it
      end

      it "does not count zero-token 2xx responses as failures" do
        3.times { create_log(response_tokens: 0, response_status: 200) }
        3.times { create_log(response_tokens: 12, response_status: 200) }

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
        ai_persona_seeded = Fabricate(:ai_persona, default_llm_id: seeded_llm.id)
        SiteSetting.ai_summarization_persona = ai_persona_seeded.id
        SiteSetting.ai_summarization_enabled = true

        3.times { create_log(response_tokens: 0, response_status: 500, llm_id: seeded_llm.id) }

        expect(described_class.new(seeded_llm.id)).to be_chill_about_it
      end
    end
  end

  def create_log(
    response_tokens:,
    response_status:,
    created_at: Time.zone.now,
    llm_id: llm_model.id
  )
    AiApiAuditLog.create!(
      provider_id: provider,
      llm_id: llm_id,
      response_tokens: response_tokens,
      response_status: response_status,
      created_at: created_at,
    )
  end
end
