# frozen_string_literal: true

require "rails_helper"

describe "Data explorer group serializer additions" do
  fab!(:group_user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  fab!(:group)
  let!(:query) { DiscourseDataExplorer::Query.create!(name: "My query", sql: "") }

  before do
    SiteSetting.data_explorer_enabled = true
    group.add(group_user)
    DiscourseDataExplorer::QueryGroup.create!(group: group, query: query)
  end

  it "query boolean is true for group user" do
    sign_in group_user
    get "/g/#{group.name}.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["group"]["has_visible_data_explorer_queries"]).to eq(true)
  end

  it "query boolean is false for group user when there are no queries" do
    query.destroy!
    sign_in group_user
    get "/g/#{group.name}.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["group"]["has_visible_data_explorer_queries"]).to eq(false)
  end

  it "does not include query boolean for anon" do
    get "/g/#{group.name}.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["group"]["has_visible_data_explorer_queries"]).to eq(nil)
  end

  it "does not include query boolean for non-group user" do
    sign_in other_user
    get "/g/#{group.name}.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["group"]["has_visible_data_explorer_queries"]).to eq(nil)
  end
end
