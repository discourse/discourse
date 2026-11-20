# frozen_string_literal: true

describe "API keys scoped to ai#manage_artifacts" do
  before { SiteSetting.discourse_ai_enabled = true }

  fab!(:admin)
  fab!(:topic_post, :post)
  fab!(:ai_artifact)
  fab!(:other_ai_artifact, :ai_artifact)

  let(:api_key) do
    key = ApiKey.create!
    ApiKeyScope.create!(resource: "ai", action: "manage_artifacts", api_key_id: key.id)
    key
  end

  let(:restricted_api_key) do
    key = ApiKey.create!
    ApiKeyScope.create!(
      resource: "ai",
      action: "manage_artifacts",
      api_key_id: key.id,
      allowed_parameters: {
        "id" => [ai_artifact.id.to_s],
      },
    )
    key
  end

  let(:headers) { { "Api-Key" => api_key.key, "Api-Username" => admin.username } }
  let(:restricted_headers) do
    { "Api-Key" => restricted_api_key.key, "Api-Username" => admin.username }
  end

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

  it "enforces artifact IDs from the path and denies collection routes when restricted" do
    get "/admin/plugins/discourse-ai/ai-artifacts/#{ai_artifact.id}.json",
        headers: restricted_headers
    expect(response.status).to eq(200)

    get "/admin/plugins/discourse-ai/ai-artifacts/#{other_ai_artifact.id}.json",
        headers: restricted_headers,
        params: {
          id: ai_artifact.id,
        }
    expect(response.status).to eq(404)

    get "/admin/plugins/discourse-ai/ai-artifacts.json", headers: restricted_headers
    expect(response.status).to eq(404)
  end

  it "cannot access unrelated endpoints" do
    get "/latest.json", headers: headers
    expect(response.status).to eq(403)
  end
end
