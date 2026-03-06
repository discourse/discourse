# frozen_string_literal: true

RSpec.describe DiscourseAi::AiCreditsController do
  fab!(:user)

  before { enable_current_plugin }

  describe "#status" do
    context "when not logged in" do
      it "returns a 403" do
        get "/discourse-ai/credits/status.json"
        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user) }

      it "returns empty result when no params provided" do
        get "/discourse-ai/credits/status.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq({ "agents" => {}, "features" => {}, "llm_models" => {} })
      end

      context "when validating parameters" do
        it "returns 400 when agent_ids exceeds maximum" do
          get "/discourse-ai/credits/status.json", params: { agent_ids: (1..101).to_a }

          expect(response.status).to eq(400)
        end

        it "returns 400 when features exceeds maximum" do
          get "/discourse-ai/credits/status.json",
              params: {
                features: (1..101).map { |i| "feature_#{i}" },
              }

          expect(response.status).to eq(400)
        end

        it "returns 400 when llm_model_ids exceeds maximum" do
          get "/discourse-ai/credits/status.json", params: { llm_model_ids: (1..101).to_a }

          expect(response.status).to eq(400)
        end

        it "accepts exactly 100 items" do
          get "/discourse-ai/credits/status.json", params: { agent_ids: (1..100).to_a }

          expect(response.status).to eq(200)
        end

        it "handles non-existent IDs gracefully" do
          get "/discourse-ai/credits/status.json", params: { agent_ids: [99_999, 88_888] }

          expect(response.status).to eq(200)
          expect(response.parsed_body["agents"]).to eq({})
        end

        it "handles mixed valid and invalid IDs" do
          llm_model = Fabricate(:llm_model, id: -10)
          ai_agent = Fabricate(:ai_agent, default_llm_id: llm_model.id)
          Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 1000)

          get "/discourse-ai/credits/status.json", params: { agent_ids: [ai_agent.id, 99_999] }

          expect(response.status).to eq(200)
          expect(response.parsed_body["agents"].keys).to contain_exactly(ai_agent.id.to_s)
        end
      end

      context "with agent_ids param" do
        fab!(:llm_model) { Fabricate(:llm_model, id: -1) }
        fab!(:ai_agent) { Fabricate(:ai_agent, default_llm_id: llm_model.id) }

        it "returns empty for agent without credit allocation" do
          get "/discourse-ai/credits/status.json", params: { agent_ids: [ai_agent.id] }

          expect(response.status).to eq(200)
          expect(response.parsed_body["agents"]).to eq({})
        end

        context "with credit allocation" do
          fab!(:llm_credit_allocation) do
            Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 1000)
          end

          it "returns credit status for agent" do
            get "/discourse-ai/credits/status.json", params: { agent_ids: [ai_agent.id] }

            expect(response.status).to eq(200)
            agent_data = response.parsed_body.dig("agents", ai_agent.id.to_s)

            expect(agent_data).to be_present
            expect(agent_data["llm_model_id"]).to eq(llm_model.id)
            expect(agent_data["credit_status"]["available"]).to eq(true)
            expect(agent_data["credit_status"]["hard_limit_reached"]).to eq(false)
            expect(agent_data["credit_status"]["daily_credits"]).to eq(1000)
            expect(agent_data["credit_status"]["credits_remaining"]).to eq(1000)
          end

          it "returns hard_limit_reached when credits exhausted" do
            llm_credit_allocation.deduct_credits!(1000)

            get "/discourse-ai/credits/status.json", params: { agent_ids: [ai_agent.id] }

            expect(response.status).to eq(200)
            agent_data = response.parsed_body.dig("agents", ai_agent.id.to_s)

            expect(agent_data["credit_status"]["available"]).to eq(false)
            expect(agent_data["credit_status"]["hard_limit_reached"]).to eq(true)
            expect(agent_data["credit_status"]["credits_remaining"]).to eq(0)
          end
        end
      end

      context "with features param" do
        fab!(:llm_model) { Fabricate(:llm_model, id: -2) }
        fab!(:ai_agent) { Fabricate(:ai_agent, default_llm_id: llm_model.id) }

        before do
          SiteSetting.ai_discover_enabled = true
          SiteSetting.ai_discover_agent = ai_agent.id
        end

        it "returns empty for feature without credit allocation" do
          get "/discourse-ai/credits/status.json", params: { features: ["discoveries"] }

          expect(response.status).to eq(200)
          expect(response.parsed_body["features"]).to eq({})
        end

        context "with credit allocation" do
          fab!(:llm_credit_allocation) do
            Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 500)
          end

          it "returns credit status for feature" do
            get "/discourse-ai/credits/status.json", params: { features: ["discoveries"] }

            expect(response.status).to eq(200)
            feature_data = response.parsed_body.dig("features", "discoveries")

            expect(feature_data).to be_present
            expect(feature_data["llm_model_id"]).to eq(llm_model.id)
            expect(feature_data["credit_status"]["available"]).to eq(true)
            expect(feature_data["credit_status"]["daily_credits"]).to eq(500)
          end

          it "returns hard_limit_reached when credits exhausted" do
            llm_credit_allocation.deduct_credits!(500)

            get "/discourse-ai/credits/status.json", params: { features: ["discoveries"] }

            expect(response.status).to eq(200)
            feature_data = response.parsed_body.dig("features", "discoveries")

            expect(feature_data["credit_status"]["available"]).to eq(false)
            expect(feature_data["credit_status"]["hard_limit_reached"]).to eq(true)
          end
        end
      end

      context "with both agent_ids and features params" do
        fab!(:llm_model) { Fabricate(:llm_model, id: -3) }
        fab!(:ai_agent) { Fabricate(:ai_agent, default_llm_id: llm_model.id) }
        fab!(:llm_credit_allocation) do
          Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 1000)
        end

        before do
          SiteSetting.ai_discover_enabled = true
          SiteSetting.ai_discover_agent = ai_agent.id
        end

        it "returns credit status for both" do
          get "/discourse-ai/credits/status.json",
              params: {
                agent_ids: [ai_agent.id],
                features: ["discoveries"],
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["agents"]).to be_present
          expect(response.parsed_body["features"]).to be_present
        end
      end

      context "with llm_model_ids param" do
        fab!(:llm_model) { Fabricate(:llm_model, id: -100) }

        it "returns empty for model without credit allocation" do
          get "/discourse-ai/credits/status.json", params: { llm_model_ids: [llm_model.id] }

          expect(response.status).to eq(200)
          expect(response.parsed_body["llm_models"]).to eq({})
        end

        context "with credit allocation" do
          fab!(:llm_credit_allocation) do
            Fabricate(:llm_credit_allocation, llm_model: llm_model, daily_credits: 2000)
          end

          it "returns credit status for LLM model" do
            get "/discourse-ai/credits/status.json", params: { llm_model_ids: [llm_model.id] }

            expect(response.status).to eq(200)
            model_data = response.parsed_body.dig("llm_models", llm_model.id.to_s)

            expect(model_data).to be_present
            expect(model_data["credit_status"]["available"]).to eq(true)
            expect(model_data["credit_status"]["hard_limit_reached"]).to eq(false)
            expect(model_data["credit_status"]["daily_credits"]).to eq(2000)
          end

          it "returns hard_limit_reached when credits exhausted" do
            llm_credit_allocation.deduct_credits!(2000)

            get "/discourse-ai/credits/status.json", params: { llm_model_ids: [llm_model.id] }

            expect(response.status).to eq(200)
            model_data = response.parsed_body.dig("llm_models", llm_model.id.to_s)

            expect(model_data["credit_status"]["available"]).to eq(false)
            expect(model_data["credit_status"]["hard_limit_reached"]).to eq(true)
          end
        end

        it "returns empty for non-seeded model" do
          custom_model = Fabricate(:llm_model)
          Fabricate(:llm_credit_allocation, llm_model: custom_model, daily_credits: 1000)

          get "/discourse-ai/credits/status.json", params: { llm_model_ids: [custom_model.id] }

          expect(response.status).to eq(200)
          expect(response.parsed_body["llm_models"]).to eq({})
        end
      end
    end
  end
end
