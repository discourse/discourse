# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiArtifactsController, type: :request do
  fab!(:admin)
  fab!(:user)
  fab!(:target_post, :post)

  before do
    enable_current_plugin
    sign_in(admin)
  end

  describe "GET #index" do
    fab!(:artifacts) { Fabricate.times(3, :ai_artifact) }

    it "returns paginated list with meta" do
      get "/admin/plugins/discourse-ai/ai-artifacts.json", params: { page: 1, per_page: 2 }

      expect(response).to be_successful
      json = response.parsed_body

      expect(json["artifacts"]).to be_an(Array)
      expect(json["artifacts"].length).to eq(2)
      expect(json["meta"]).to include("total", "page", "per_page", "has_more")
      expect(json["meta"]["total"]).to eq(AiArtifact.count)
      expect(json["meta"]["page"]).to eq(1)
      expect(json["meta"]["per_page"]).to eq(2)
      expect(json["meta"]["has_more"]).to eq(true)
    end

    it "clamps per_page to max" do
      get "/admin/plugins/discourse-ai/ai-artifacts.json", params: { per_page: 5000 }
      expect(response).to be_successful
      expect(response.parsed_body.dig("meta", "per_page")).to eq(100)
    end
  end

  describe "GET #show" do
    fab!(:artifact, :ai_artifact)

    it "returns a single artifact" do
      get "/admin/plugins/discourse-ai/ai-artifacts/#{artifact.id}.json"

      expect(response).to be_successful
      json = response.parsed_body
      expect(json.dig("ai_artifact", "id")).to eq(artifact.id)
      expect(json.dig("ai_artifact", "name")).to eq(artifact.name)
    end
  end

  describe "POST #create" do
    it "keeps form-encoded private artifacts inaccessible to anonymous users" do
      private_topic = Fabricate(:private_message_topic, user: user)
      private_post = Fabricate(:post, topic: private_topic, user: user)
      private_html = "<div>Private artifact source</div>"

      post "/admin/plugins/discourse-ai/ai-artifacts.json",
           params: {
             ai_artifact: {
               user_id: admin.id,
               post_id: private_post.id,
               name: "Private artifact",
               html: private_html,
               metadata: {
                 public: false,
               },
             },
           }

      expect(response).to have_http_status(:created)
      artifact = AiArtifact.find(response.parsed_body.dig("ai_artifact", "id"))

      delete "/session/#{admin.username}.json"
      get "/discourse-ai/ai-bot/artifacts/#{artifact.id}"

      expect(response.body).not_to include(ERB::Util.html_escape(private_html))
      expect(response).to have_http_status(:not_found)
    end

    it "creates an artifact" do
      params = {
        ai_artifact: {
          user_id: admin.id,
          post_id: target_post.id,
          name: "Admin Created",
          html: "<div>hello</div>",
          css: ".x { color: red; }",
          js: "console.log('x')",
          metadata: {
            public: false,
          },
        },
      }

      expect {
        post "/admin/plugins/discourse-ai/ai-artifacts.json",
             params: params.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
      }.to change(AiArtifact, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("ai_artifact", "name")).to eq("Admin Created")
    end
  end

  describe "PUT #update" do
    fab!(:artifact, :ai_artifact)

    it "updates fields" do
      put "/admin/plugins/discourse-ai/ai-artifacts/#{artifact.id}.json",
          params: { ai_artifact: { name: "Updated Name", metadata: { public: true } } }.to_json,
          headers: {
            "CONTENT_TYPE" => "application/json",
          }

      expect(response).to be_successful
      artifact.reload
      expect(artifact.name).to eq("Updated Name")
      expect(artifact.metadata["public"]).to eq(true)
    end
  end

  describe "DELETE #destroy" do
    fab!(:artifact, :ai_artifact)

    it "removes the artifact" do
      expect { delete "/admin/plugins/discourse-ai/ai-artifacts/#{artifact.id}.json" }.to change(
        AiArtifact,
        :count,
      ).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  context "when not admin" do
    before { sign_in(user) }

    it "blocks access" do
      get "/admin/plugins/discourse-ai/ai-artifacts.json"
      expect(response.status).to eq(404)
    end
  end
end
