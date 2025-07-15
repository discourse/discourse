# frozen_string_literal: true

require "rails_helper"

describe "API keys scoped to query#run" do
  before { SiteSetting.data_explorer_enabled = true }

  fab!(:query1) do
    DiscourseDataExplorer::Query.create!(name: "Query 1", sql: "SELECT 1 AS query1_res")
  end
  fab!(:query2) do
    DiscourseDataExplorer::Query.create!(name: "Query 2", sql: "SELECT 1 AS query2_res")
  end
  fab!(:admin)

  let(:all_queries_api_key) do
    key = ApiKey.create!
    ApiKeyScope.create!(
      resource: "discourse_data_explorer",
      action: "run_queries",
      api_key_id: key.id,
    )
    key
  end

  let(:single_query_api_key) do
    key = ApiKey.create!
    ApiKeyScope.create!(
      resource: "discourse_data_explorer",
      action: "run_queries",
      api_key_id: key.id,
      allowed_parameters: {
        "id" => [query1.id.to_s],
      },
    )
    key
  end

  it "cannot hit any other endpoints" do
    get "/latest.json",
        headers: {
          "Api-Key" => all_queries_api_key.key,
          "Api-Username" => admin.username,
        }
    expect(response.status).to eq(403)

    get "/latest.json",
        headers: {
          "Api-Key" => single_query_api_key.key,
          "Api-Username" => admin.username,
        }
    expect(response.status).to eq(403)

    get "/u/#{admin.username}.json",
        headers: {
          "Api-Key" => all_queries_api_key.key,
          "Api-Username" => admin.username,
        }
    expect(response.status).to eq(403)

    get "/u/#{admin.username}.json",
        headers: {
          "Api-Key" => single_query_api_key.key,
          "Api-Username" => admin.username,
        }
    expect(response.status).to eq(403)
  end

  it "can only run the queries they're allowed to run" do
    expect {
      post "/admin/plugins/explorer/queries/#{query1.id}/run.json",
           headers: {
             "Api-Key" => single_query_api_key.key,
             "Api-Username" => admin.username,
           }
    }.to change { query1.reload.last_run_at }
    expect(response.status).to eq(200)
    expect(response.parsed_body["success"]).to eq(true)
    expect(response.parsed_body["columns"]).to eq(["query1_res"])

    expect {
      post "/admin/plugins/explorer/queries/#{query2.id}/run.json",
           headers: {
             "Api-Key" => single_query_api_key.key,
             "Api-Username" => admin.username,
           }
    }.not_to change { query2.reload.last_run_at }
    expect(response.status).to eq(403)
  end

  it "can run all queries if they're not restricted to any queries" do
    expect {
      post "/admin/plugins/explorer/queries/#{query1.id}/run.json",
           headers: {
             "Api-Key" => all_queries_api_key.key,
             "Api-Username" => admin.username,
           }
    }.to change { query1.reload.last_run_at }
    expect(response.status).to eq(200)
    expect(response.parsed_body["success"]).to eq(true)
    expect(response.parsed_body["columns"]).to eq(["query1_res"])

    expect {
      post "/admin/plugins/explorer/queries/#{query2.id}/run.json",
           headers: {
             "Api-Key" => all_queries_api_key.key,
             "Api-Username" => admin.username,
           }
    }.to change { query2.reload.last_run_at }
    expect(response.status).to eq(200)
    expect(response.parsed_body["success"]).to eq(true)
    expect(response.parsed_body["columns"]).to eq(["query2_res"])
  end
end
