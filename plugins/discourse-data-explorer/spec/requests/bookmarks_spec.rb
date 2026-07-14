# frozen_string_literal: true

RSpec.describe "Data Explorer bookmarks" do
  fab!(:admin_user, :admin)
  fab!(:user)
  fab!(:group)
  fab!(:query) do
    Fabricate(
      :query,
      name: "Private revenue report",
      description: "Secret revenue report description",
      sql: "SELECT 1",
      user: admin_user,
    )
  end

  before do
    SiteSetting.data_explorer_enabled = true
    group.add(user)
    register_test_bookmarkable(DiscourseDataExplorer::QueryGroupBookmarkable)
  end

  after { DiscoursePluginRegistry.reset_register!(:bookmarkables) }

  it "does not expose hidden query bookmark metadata in bookmark JSON or ICS responses" do
    query_group = Fabricate(:query_group, query: query, group: group)
    bookmark =
      Fabricate(
        :bookmark,
        user: user,
        bookmarkable: query_group,
        name: nil,
        reminder_at: 1.day.from_now,
      )

    sign_in(user)

    get "/u/#{user.username}/bookmarks.json"

    expect(response.status).to eq(200)
    expect(
      response
        .parsed_body
        .dig("user_bookmark_list", "bookmarks")
        .map { |bookmark_data| bookmark_data["id"] },
    ).to contain_exactly(bookmark.id)
    expect(response.body).to include(query.name)
    expect(response.body).to include(query.description)

    get "/u/#{user.username}/bookmarks.ics"

    expect(response.status).to eq(200)
    expect(response.body).to include(query.name)

    query.update!(hidden: true)

    get "/u/#{user.username}/bookmarks.json"

    expect(response.status).to eq(200)
    json_body = response.body

    get "/u/#{user.username}/bookmarks.ics"

    expect(response.status).to eq(200)
    ics_body = response.body

    aggregate_failures do
      expect(json_body).not_to include(query.name)
      expect(json_body).not_to include(query.description)
      expect(ics_body).not_to include(query.name)
      expect(ics_body).not_to include(query.description)
    end
  end

  it "keeps hidden query bookmarks visible to admins" do
    query_group = Fabricate(:query_group, query: query, group: group)
    Fabricate(
      :bookmark,
      user: admin_user,
      bookmarkable: query_group,
      name: nil,
      reminder_at: 1.day.from_now,
    )

    query.update!(hidden: true)

    sign_in(admin_user)

    get "/u/#{admin_user.username}/bookmarks.json"

    expect(response.status).to eq(200)
    expect(response.body).to include(query.name)
    expect(response.body).to include(query.description)

    get "/u/#{admin_user.username}/bookmarks.ics"

    expect(response.status).to eq(200)
    expect(response.body).to include(query.name)
  end

  it "does not expose detached query bookmark metadata in bookmark JSON or ICS responses" do
    query_group = Fabricate(:query_group, query: query, group: group)
    Fabricate(
      :bookmark,
      user: user,
      bookmarkable: query_group,
      name: nil,
      reminder_at: 1.day.from_now,
    )

    sign_in(user)

    get "/u/#{user.username}/bookmarks.json"

    expect(response.status).to eq(200)
    expect(response.body).to include(query.name)
    expect(response.body).to include(query.description)

    get "/u/#{user.username}/bookmarks.ics"

    expect(response.status).to eq(200)
    expect(response.body).to include(query.name)

    query_group.destroy!

    get "/u/#{user.username}/bookmarks.json"

    expect(response.status).to eq(200)
    json_body = response.body

    get "/u/#{user.username}/bookmarks.ics"

    expect(response.status).to eq(200)
    ics_body = response.body

    aggregate_failures do
      expect(json_body).not_to include(query.name)
      expect(json_body).not_to include(query.description)
      expect(ics_body).not_to include(query.name)
      expect(ics_body).not_to include(query.description)
    end
  end
end
