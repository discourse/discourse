# frozen_string_literal: true

RSpec.describe "Path-restricted API key scopes" do
  fab!(:admin)
  fab!(:topic)
  fab!(:other_topic, :topic)

  def headers_for(api_key)
    { "Api-Key" => api_key.key, "Api-Username" => admin.username }
  end

  def topic_read_key(allowed_parameters)
    Fabricate(:api_key, user: admin).tap do |api_key|
      ApiKeyScope.create!(
        api_key_id: api_key.id,
        resource: "topics",
        action: "read",
        allowed_parameters: allowed_parameters,
      )
    end
  end

  it "uses the recognized topic path instead of an injected selector" do
    api_key = topic_read_key("topic_id" => [topic.id.to_s])

    get "/t/#{other_topic.id}/posts.json",
        headers: headers_for(api_key),
        params: {
          topic_id: topic.id,
        }

    expect(response.status).to eq(403)
    expect(response.body).not_to include(other_topic.title)
  end

  it "does not satisfy an external ID restriction on a numeric topic route" do
    api_key = topic_read_key("external_id" => ["allowed-external-id"])

    get "/t/#{topic.id}/posts.json",
        headers: headers_for(api_key),
        params: {
          external_id: "allowed-external-id",
        }

    expect(response.status).to eq(403)
    expect(response.body).not_to include(topic.title)
  end

  it "allows a matching recognized topic path" do
    api_key = topic_read_key("topic_id" => [topic.id.to_s])

    get "/t/#{topic.id}/posts.json", headers: headers_for(api_key)

    expect(response.status).to eq(200)
  end
end
