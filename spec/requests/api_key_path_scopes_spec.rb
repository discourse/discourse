# frozen_string_literal: true

RSpec.describe "Path-restricted API key scopes" do
  fab!(:admin)
  fab!(:topic)
  fab!(:other_topic, :topic)
  fab!(:restricted_category, :category)
  fab!(:secret_category, :category)
  fab!(:restricted_topic) { Fabricate(:topic, category: restricted_category) }
  fab!(:secret_topic) { Fabricate(:topic, category: secret_category) }

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

  def read_lists_key(allowed_parameters)
    Fabricate(:api_key, user: admin).tap do |api_key|
      ApiKeyScope.create!(
        api_key_id: api_key.id,
        resource: "topics",
        action: "read_lists",
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

  it "rejects redundant record selectors outside a restricted path" do
    api_key = topic_read_key("topic_id" => [topic.id.to_s])

    get "/t/#{topic.id}/posts.json", headers: headers_for(api_key), params: { topic_id: topic.id }

    expect(response.status).to eq(403)
    expect(response.parsed_body["errors"]).to be_present
  end

  it "allows a matching recognized topic path" do
    api_key = topic_read_key("topic_id" => [topic.id.to_s])

    get "/t/#{topic.id}/posts.json", headers: headers_for(api_key)

    expect(response.status).to eq(200)
  end

  it "does not authorize a global list using a decoy category_id query parameter" do
    api_key = read_lists_key("category_id" => [restricted_category.id.to_s])

    get "/latest.json",
        headers: headers_for(api_key),
        params: {
          category_id: restricted_category.id,
        }

    expect(response.status).to eq(403)
    expect(response.body).not_to include(secret_topic.title)
  end

  it "allows the recognized category list route within the delegated category" do
    api_key = read_lists_key("category_id" => [restricted_category.id.to_s])

    get "/c/#{restricted_category.slug}/#{restricted_category.id}/l/latest.json",
        headers: headers_for(api_key)

    expect(response.status).to eq(200)
    expect(response.body).to include(restricted_topic.title)
  end

  it "does not authorize another category's list route" do
    api_key = read_lists_key("category_id" => [restricted_category.id.to_s])

    get "/c/#{secret_category.slug}/#{secret_category.id}/l/latest.json",
        headers: headers_for(api_key)

    expect(response.status).to eq(403)
    expect(response.body).not_to include(secret_topic.title)
  end
end
