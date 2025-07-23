# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiLlmQuotasController do
  fab!(:admin)
  fab!(:group)
  fab!(:llm_model)

  before do
    enable_current_plugin
    sign_in(admin)
    SiteSetting.ai_bot_enabled = true
  end

  describe "#index" do
    fab!(:quota) { Fabricate(:llm_quota, llm_model: llm_model, group: group) }
    fab!(:quota2) { Fabricate(:llm_quota, llm_model: llm_model) }

    it "lists all quotas for a given LLM" do
      get "/admin/plugins/discourse-ai/quotas.json"

      expect(response.status).to eq(200)

      quotas = response.parsed_body["quotas"]
      expect(quotas.length).to eq(2)
      expect(quotas.map { |q| q["id"] }).to contain_exactly(quota.id, quota2.id)
    end
  end

  describe "#create" do
    let(:valid_params) do
      {
        quota: {
          group_id: group.id,
          llm_model_id: llm_model.id,
          max_tokens: 1000,
          max_usages: 100,
          duration_seconds: 1.day.to_i,
        },
      }
    end

    it "creates a new quota with valid params" do
      expect {
        post "/admin/plugins/discourse-ai/quotas.json", params: valid_params
        expect(response.status).to eq(201)
      }.to change(LlmQuota, :count).by(1)

      quota = LlmQuota.last
      expect(quota.group_id).to eq(group.id)
      expect(quota.max_tokens).to eq(1000)
    end

    it "fails with invalid params" do
      post "/admin/plugins/discourse-ai/quotas.json",
           params: {
             quota: valid_params[:quota].except(:group_id),
           }

      expect(response.status).to eq(422)
      expect(LlmQuota.count).to eq(0)
    end
  end

  describe "#update" do
    fab!(:quota) { Fabricate(:llm_quota, llm_model: llm_model, group: group) }

    it "updates quota with valid params" do
      put "/admin/plugins/discourse-ai/quotas/#{quota.id}.json",
          params: {
            quota: {
              max_tokens: 2000,
            },
          }

      expect(response.status).to eq(200)
      expect(quota.reload.max_tokens).to eq(2000)
    end

    it "fails with invalid params" do
      put "/admin/plugins/discourse-ai/quotas/#{quota.id}.json",
          params: {
            quota: {
              duration_seconds: 0,
            },
          }

      expect(response.status).to eq(422)
      expect(quota.reload.duration_seconds).not_to eq(0)
    end
  end

  describe "#destroy" do
    fab!(:quota) { Fabricate(:llm_quota, llm_model: llm_model, group: group) }

    it "deletes the quota" do
      delete "/admin/plugins/discourse-ai/quotas/#{quota.id}.json"

      expect(response.status).to eq(204)
      expect { quota.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "returns 404 for non-existent quota" do
      delete "/admin/plugins/discourse-ai/quotas/9999.json"

      expect(response.status).to eq(404)
    end
  end
end
