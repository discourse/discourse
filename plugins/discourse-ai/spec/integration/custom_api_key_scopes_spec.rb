# frozen_string_literal: true

describe "API keys scoped to discourse_ai#manage_artifacts" do
  before { SiteSetting.discourse_ai_enabled = true }

  fab!(:admin)
  fab!(:topic_post, :post)
  fab!(:ai_artifact)

  let(:api_key) do
    key = ApiKey.create!
    ApiKeyScope.create!(resource: "discourse_ai", action: "manage_artifacts", api_key_id: key.id)
    key
  end

  let(:headers) { { "Api-Key" => api_key.key, "Api-Username" => admin.username } }

  it "can list artifacts" do
    get "/admin/plugins/discourse-ai/ai-artifacts.json", headers: headers
    expect(response.status).to eq(200)
  end

  it "can show an artifact" do
    get "/admin/plugins/discourse-ai/ai-artifacts/#{ai_artifact.id}.json", headers: headers
    expect(response.status).to eq(200)
  end

  it "can create an artifact" do
    post "/admin/plugins/discourse-ai/ai-artifacts.json",
         headers: headers,
         params: {
           ai_artifact: {
             user_id: admin.id,
             post_id: topic_post.id,
             name: "Test Artifact",
             html: "<div>hello</div>",
           },
         }
    expect(response.status).to eq(201)
  end

  it "can update an artifact" do
    put "/admin/plugins/discourse-ai/ai-artifacts/#{ai_artifact.id}.json",
        headers: headers,
        params: {
          ai_artifact: {
            name: "Updated Name",
          },
        }
    expect(response.status).to eq(200)
  end

  it "can destroy an artifact" do
    delete "/admin/plugins/discourse-ai/ai-artifacts/#{ai_artifact.id}.json", headers: headers
    expect(response.status).to eq(204)
  end

  it "cannot access unrelated endpoints" do
    get "/latest.json", headers: headers
    expect(response.status).to eq(403)
  end
end
