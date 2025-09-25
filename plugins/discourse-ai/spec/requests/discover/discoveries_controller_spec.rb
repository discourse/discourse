# frozen_string_literal: true

RSpec.describe DiscourseAi::AiBot::BotController do
  fab!(:user)

  before do
    enable_current_plugin
    sign_in(user)
    SiteSetting.ai_discover_enabled = true
  end

  describe "#reply" do
    fab!(:group)
    fab!(:ai_persona) { Fabricate(:ai_persona, allowed_group_ids: [group.id], default_llm_id: 1) }

    before { SiteSetting.ai_discover_persona = ai_persona.id }

    context "when the user doesn't have access to the persona" do
      it "returns a 403" do
        get "/discourse-ai/discoveries/reply", params: { query: "What is Discourse?" }

        expect(response.status).to eq(403)
      end
    end

    context "when the user is allowed to use discover" do
      before do
        SiteSetting.ai_discover_persona = ai_persona.id
        group.add(user)
      end

      it "returns a 200 and queues a job to reply" do
        expect {
          get "/discourse-ai/discoveries/reply", params: { query: "What is Discourse?" }
        }.to change(Jobs::StreamDiscoverReply.jobs, :size).by(1)

        expect(response.status).to eq(200)
      end

      it "retues a 400 if the query is missing" do
        get "/discourse-ai/discoveries/reply"

        expect(response.status).to eq(400)
      end
    end
  end

  describe "#continue_convo" do
    fab!(:group)
    fab!(:llm_model)
    fab!(:ai_persona) do
      persona = Fabricate(:ai_persona, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
      persona.create_user!
      persona
    end
    let(:query) { "What is Discourse?" }
    let(:context) { "Discourse is an open-source discussion platform." }

    context "when the user is allowed to discover" do
      before do
        SiteSetting.ai_discover_persona = ai_persona.id
        group.add(user)
      end

      it "returns a 200 and creates a private message topic" do
        expect {
          post "/discourse-ai/discoveries/continue-convo",
               params: {
                 user_id: user.id,
                 query: query,
                 context: context,
               }
        }.to change(Topic, :count).by(1)

        expect(response.status).to eq(200)
        expect(response.parsed_body["topic_id"]).to be_present
      end

      it "returns invalid parameters if the user_id is missing" do
        post "/discourse-ai/discoveries/continue-convo", params: { query: query, context: context }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include("user_id")
      end

      it "returns invalid parameters if the query is missing" do
        post "/discourse-ai/discoveries/continue-convo",
             params: {
               user_id: user.id,
               context: context,
             }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include("query")
      end

      it "returns invalid parameters if the context is missing" do
        post "/discourse-ai/discoveries/continue-convo", params: { user_id: user.id, query: query }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include("context")
      end
    end
  end
end
