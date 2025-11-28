# frozen_string_literal: true

RSpec.describe DiscourseAi::CreditStatusChecker do
  # Contract validations are tested through the service call tests below

  describe ".call" do
    subject(:result) { described_class.call(params:) }

    let(:params) { {} }

    context "when no parameters provided" do
      it { is_expected.to run_successfully }

      it "returns empty result" do
        expect(result[:personas]).to eq({})
        expect(result[:features]).to eq({})
        expect(result[:llm_models]).to eq({})
      end
    end

    context "when parameters exceed limits" do
      let(:params) { { persona_ids: (1..101).to_a } }

      it { is_expected.to fail_a_contract }
    end

    context "with persona_ids param" do
      fab!(:llm_model) { Fabricate(:llm_model, id: -1) }
      fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

      let(:params) { { persona_ids: [ai_persona.id] } }

      context "without credit allocation" do
        it { is_expected.to run_successfully }

        it "returns empty personas hash" do
          expect(result[:personas]).to eq({})
        end
      end

      context "with non-existent persona IDs" do
        let(:params) { { persona_ids: [99_999] } }

        it { is_expected.to run_successfully }

        it "returns empty personas hash" do
          expect(result[:personas]).to eq({})
        end
      end

      context "with credit allocation" do
        fab!(:llm_credit_allocation) do
          Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 1000)
        end

        it { is_expected.to run_successfully }

        it "returns credit status for persona" do
          persona_data = result[:personas][ai_persona.id]

          expect(persona_data).to be_present
          expect(persona_data[:llm_model_id]).to eq(llm_model.id)
          expect(persona_data[:credit_status][:available]).to eq(true)
          expect(persona_data[:credit_status][:daily_credits]).to eq(1000)
        end

        it "returns hard_limit_reached when credits exhausted" do
          llm_credit_allocation.deduct_credits!(1000)

          persona_data = result[:personas][ai_persona.id]

          expect(persona_data[:credit_status][:available]).to eq(false)
          expect(persona_data[:credit_status][:hard_limit_reached]).to eq(true)
        end

        it "batch loads multiple personas efficiently" do
          persona2 = Fabricate(:ai_persona, default_llm_id: llm_model.id)
          params[:persona_ids] = [ai_persona.id, persona2.id]

          queries = track_sql_queries { result }

          select_queries = queries.select { |q| q.include?("SELECT") && !q.include?("SELECT 1") }

          expect(select_queries.length).to be <= 5
        end

        it "handles mixed valid and invalid IDs" do
          params[:persona_ids] = [ai_persona.id, 99_999]

          expect(result[:personas].keys).to contain_exactly(ai_persona.id)
        end
      end
    end

    context "with features param" do
      fab!(:llm_model) { Fabricate(:llm_model, id: -2) }
      fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }

      let(:params) { { features: ["discoveries"] } }

      before do
        SiteSetting.ai_discover_enabled = true
        SiteSetting.ai_discover_persona = ai_persona.id
      end

      context "without credit allocation" do
        it { is_expected.to run_successfully }

        it "returns empty features hash" do
          expect(result[:features]).to eq({})
        end
      end

      context "with non-existent features" do
        let(:params) { { features: ["nonexistent_feature"] } }

        it { is_expected.to run_successfully }

        it "returns empty features hash" do
          expect(result[:features]).to eq({})
        end
      end

      context "with credit allocation" do
        fab!(:llm_credit_allocation) do
          Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 500)
        end

        it { is_expected.to run_successfully }

        it "returns credit status for feature" do
          feature_data = result[:features]["discoveries"]

          expect(feature_data).to be_present
          expect(feature_data[:llm_model_id]).to eq(llm_model.id)
          expect(feature_data[:credit_status][:available]).to eq(true)
        end

        it "returns hard_limit_reached when credits exhausted" do
          llm_credit_allocation.deduct_credits!(500)

          feature_data = result[:features]["discoveries"]

          expect(feature_data[:credit_status][:available]).to eq(false)
          expect(feature_data[:credit_status][:hard_limit_reached]).to eq(true)
        end
      end
    end

    context "with llm_model_ids param" do
      fab!(:llm_model) { Fabricate(:llm_model, id: -3) }

      let(:params) { { llm_model_ids: [llm_model.id] } }

      context "without credit allocation" do
        it { is_expected.to run_successfully }

        it "returns empty llm_models hash" do
          expect(result[:llm_models]).to eq({})
        end
      end

      context "with non-existent model IDs" do
        let(:params) { { llm_model_ids: [99_999] } }

        it { is_expected.to run_successfully }

        it "returns empty llm_models hash" do
          expect(result[:llm_models]).to eq({})
        end
      end

      context "with credit allocation" do
        fab!(:llm_credit_allocation) do
          Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 2000)
        end

        it { is_expected.to run_successfully }

        it "returns credit status for LLM model" do
          model_data = result[:llm_models][llm_model.id]

          expect(model_data).to be_present
          expect(model_data[:credit_status][:available]).to eq(true)
          expect(model_data[:credit_status][:daily_credits]).to eq(2000)
        end

        it "returns hard_limit_reached when credits exhausted" do
          llm_credit_allocation.deduct_credits!(2000)

          model_data = result[:llm_models][llm_model.id]

          expect(model_data[:credit_status][:available]).to eq(false)
          expect(model_data[:credit_status][:hard_limit_reached]).to eq(true)
        end

        it "returns empty for non-seeded model" do
          custom_model = Fabricate(:llm_model)
          Fabricate(:llm_credit_allocation, llm_model: custom_model, daily_credits: 1000)
          params[:llm_model_ids] = [custom_model.id]

          expect(result[:llm_models]).to eq({})
        end

        it "batch loads multiple models efficiently" do
          model2 = Fabricate(:llm_model, id: -4)
          Fabricate(:llm_credit_allocation, llm_model: model2, daily_credits: 1000)
          params[:llm_model_ids] = [llm_model.id, model2.id]

          queries = track_sql_queries { result }

          select_queries = queries.select { |q| q.include?("SELECT") && !q.include?("SELECT 1") }

          expect(select_queries.length).to be <= 4
        end
      end
    end

    context "with combined parameters" do
      fab!(:llm_model) { Fabricate(:llm_model, id: -6) }
      fab!(:ai_persona) { Fabricate(:ai_persona, default_llm_id: llm_model.id) }
      fab!(:llm_credit_allocation) do
        Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 1000)
      end

      let(:params) do
        { persona_ids: [ai_persona.id], features: ["discoveries"], llm_model_ids: [llm_model.id] }
      end

      before do
        SiteSetting.ai_discover_enabled = true
        SiteSetting.ai_discover_persona = ai_persona.id
      end

      it { is_expected.to run_successfully }

      it "handles multiple parameter types simultaneously" do
        expect(result[:personas]).to be_present
        expect(result[:features]).to be_present
        expect(result[:llm_models]).to be_present
      end
    end

    context "with input sanitization" do
      it "sanitizes persona IDs to integers" do
        params[:persona_ids] = ["1", "2", nil, ""]

        expect(result[:personas]).to eq({})
      end

      it "sanitizes feature names to strings" do
        params[:features] = [:discoveries, nil, ""]

        # Just verify it doesn't crash - the features hash will be empty since no matching features
        expect(result[:features]).to eq({})
      end

      it "removes duplicates from input" do
        llm_model = Fabricate(:llm_model, id: -7)
        Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 1000)
        params[:llm_model_ids] = [llm_model.id, llm_model.id, llm_model.id]

        expect(result[:llm_models].keys.length).to eq(1)
      end
    end
  end
end
