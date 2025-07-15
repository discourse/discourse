# frozen_string_literal: true

require "rails_helper"

describe SearchController do
  fab!(:admin)
  fab!(:group) do
    Fabricate(
      :group,
      assignable_level: Group::ALIAS_LEVELS[:everyone],
      flair_upload: Fabricate(:upload),
    )
  end

  before do
    SiteSetting.assign_enabled = true
    sign_in(admin)
  end

  after { Discourse.redis.flushdb }

  it "include assigned group in search result" do
    SearchIndexer.enable
    SiteSetting.use_pg_headlines_for_excerpt = true

    post = Fabricate(:post, topic: Fabricate(:topic, title: "this is an awesome title"))

    Assigner.new(post.topic, admin).assign(group)

    get "/search/query.json", params: { term: "awesome" }

    expect(response.status).to eq(200)
    assigned_to_group_data = response.parsed_body["topics"][0]["assigned_to_group"]

    expect(assigned_to_group_data["id"]).to eq(group.id)
    expect(assigned_to_group_data["name"]).to eq(group.name)
  end

  it "does not result in N+1 queries when search returns multiple results" do
    SearchIndexer.enable
    SiteSetting.assigns_public = true
    post = Fabricate(:post, topic: Fabricate(:topic, title: "this is an awesome title"))

    get "/search/query.json", params: { term: "awesome" }

    initial_sql_queries_count =
      track_sql_queries { get "/search/query.json", params: { term: "awesome" } }.count

    Fabricate(:post, topic: Fabricate(:topic, title: "this is an awesome title 2"))
    Fabricate(:post, topic: Fabricate(:topic, title: "this is an awesome title 3"))
    new_sql_queries_count =
      track_sql_queries { get "/search/query.json", params: { term: "awesome" } }.count
    expect(new_sql_queries_count).to eq(initial_sql_queries_count)
  end
end
