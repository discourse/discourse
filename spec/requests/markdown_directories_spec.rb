# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Markdown directories" do
  fab!(:category) { Fabricate(:category, description: "<p>A useful category.</p>") }
  fab!(:child) { Fabricate(:category, parent_category: category) }
  fab!(:tag) do
    Fabricate(:tag, public_topic_count: 1, staff_topic_count: 1, description: "A useful tag.")
  end

  before { SiteSetting.tagging_enabled = true }

  after { category.clear_url_cache }

  it "serves both directories by suffix and negotiation, with discovery on HTML" do
    %w[categories tags].each do |directory|
      get "/#{directory}.md", headers: { "ACCEPT" => "application/json" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/markdown")

      get "/#{directory}", headers: { "ACCEPT" => "text/markdown" }
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/markdown")
      expect(response.headers["Vary"]).to include("Accept")

      get "/#{directory}", headers: { "ACCEPT" => "text/html" }
      expect(response.media_type).to eq("text/html")
      expect(response.headers["Link"]).to include("/#{directory}.md")
      expect(response.body).to include('type="text/markdown"', "/#{directory}.md")

      get "/#{directory}.json", headers: { "ACCEPT" => "text/markdown" }
      expect(response.media_type).to eq("application/json")
    end
  end

  it "renders category descriptions, children, and parent links" do
    get "/categories.md?include_subcategories=true"

    expect(response.body).to include(
      "[#{category.name}](#{Discourse.base_url_no_prefix}#{category.url}.md)",
      "[#{child.name}](#{Discourse.base_url_no_prefix}#{child.url}.md)",
      "Parent: [#{category.name}]",
      "A useful category.",
    )
    expect(response.body).not_to include("<p>")
  end

  it "uses category permissions for anonymous and authorized readers" do
    restricted = Fabricate(:category, read_restricted: true)
    restricted.set_permissions(staff: :full)

    get "/categories.md"
    expect(response.body).not_to include(restricted.name)

    sign_in(Fabricate(:admin))
    get "/categories.md"
    expect(response.body).to include(restricted.name)
  end

  it "uses the native tag visibility rules for anonymous readers and admins" do
    restricted = Fabricate(:tag, public_topic_count: 1, staff_topic_count: 1)
    Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [restricted.name])
    pm_only = Fabricate(:tag, public_topic_count: 0, staff_topic_count: 0, pm_topic_count: 1)
    synonym = Fabricate(:tag, target_tag: tag, public_topic_count: 1)

    get "/tags.md"
    expect(response.body).to include(
      "[#{tag.name}](#{Discourse.base_url_no_prefix}#{tag.url}.md)",
      tag.description,
    )
    expect(response.body).not_to include(restricted.name, pm_only.name, synonym.name)

    sign_in(Fabricate(:admin))
    get "/tags.md"
    expect(response.body).to include(restricted.name)
    expect(response.body).to include(pm_only.name)
    expect(response.body).not_to include(synonym.name)
  end

  it "includes grouped tags and deduplicates category-associated tags" do
    grouped = Fabricate(:tag, public_topic_count: 1)
    Fabricate(:tag_group, tag_names: [grouped.name])
    category.tags << tag

    [false, true].each do |grouped_layout|
      SiteSetting.tags_listed_by_group = grouped_layout
      get "/tags.md"
      expect(response.body.scan(/^## \[(.*?)\]/).flatten).to contain_exactly(tag.name, grouped.name)
    end
  end

  it "uses the native category ordering and pagination" do
    sign_in(Fabricate(:user))
    SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}"
    stub_const(CategoryList, :CATEGORIES_PER_PAGE, 2) do
      [1, 2].each do |page|
        get "/categories.json", params: { page: page }
        names = response.parsed_body["category_list"]["categories"].map { |entry| entry["name"] }

        get "/categories.md", params: { page: page }
        expect(response.body.scan(/^## \[(.*?)\]/).flatten).to eq(names)
      end
    end
  end

  it "respects the native category layout's subcategory selection" do
    SiteSetting.desktop_category_page_style = "categories_only"
    SiteSetting.mobile_category_page_style = "categories_only"
    get "/categories.md"
    expect(response.body).to include(category.name)
    expect(response.body).not_to include(child.name)
  end

  it "omits next-page links when category pagination is disabled" do
    SiteSetting.lazy_load_categories_groups = ""
    stub_const(CategoryList, :CATEGORIES_PER_PAGE, 2) do
      get "/categories.md"
      expect(response.body.scan(/^## /).size).to be >= 2
      expect(response.body).not_to include("[Next page]")
    end
  end

  it "links only to existing native category pages, without counting appended children" do
    sign_in(Fabricate(:user))
    SiteSetting.lazy_load_categories_groups = "#{Group::AUTO_GROUPS[:everyone]}"
    SiteSetting.fixed_category_positions = true
    category.update!(position: 1000)
    Fabricate(:category, parent_category: category)

    stub_const(CategoryList, :CATEGORIES_PER_PAGE, 2) do
      url = "/categories.md"
      10.times do
        get url
        expect(response.body).to include("## [")
        next_url = response.body[/\[Next page\]\(([^)]+)\)/, 1]
        break unless next_url
        url = URI(next_url).request_uri
      end
      expect(response.body).not_to include("[Next page]")
      expect(response.body).to include(category.name, child.name)
    end
  end

  it "renders localized directory entries with localization preloading" do
    SiteSetting.content_localization_enabled = true
    category.update!(locale: "ja")
    child.update!(locale: "ja")
    tag.update!(locale: "ja")
    Fabricate(
      :category_localization,
      category: category,
      locale: "en",
      name: "Translated category",
      description: "<p>Translated description.</p>",
    )
    Fabricate(:category_localization, category: child, locale: "en", name: "Translated child")
    Fabricate(
      :tag_localization,
      tag: tag,
      locale: "en",
      name: "translated-tag",
      description: "Translated tag description.",
    )

    queries = track_sql_queries { get "/categories.md?include_subcategories=true" }
    expect(response.body).to include(
      "Translated category",
      "Translated child",
      "Translated description.",
      "Parent: [Translated category]",
    )
    expect(queries.grep(/FROM "category_localizations"/).length).to be <= 2

    get "/tags.md"
    expect(response.body).to include("translated-tag", "Translated tag description.")
  end

  it "uses subfolder-safe links in directories and topic-list navigation" do
    set_subfolder "/forum"
    get "/latest.md"
    expect(response.body).to include(
      "\n[Latest](#{Discourse.base_url}/latest.md) · [Categories](#{Discourse.base_url}/categories.md) · [Tags](#{Discourse.base_url}/tags.md)\n",
    )

    get "/categories.md?include_subcategories=true"
    expect(response.body).to include("#{Discourse.base_url_no_prefix}#{child.url}.md")
    expect(response.body).not_to include("/forum/forum/")
  end

  it "omits the tags link and rejects the directory when tagging is disabled" do
    SiteSetting.tagging_enabled = false
    get "/latest.md"
    expect(response.body).to include("/categories.md")
    expect(response.body).not_to include("/tags.md")

    get "/tags.md"
    expect(response).to have_http_status(:not_found)
  end

  it "renders an empty tag directory without a next page" do
    tag.update!(public_topic_count: 0)
    get "/tags.md"
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("No entries to display.")
    expect(response.body).not_to include("[Next page]")
  end

  it "keeps directories behind the Markdown feature setting" do
    SiteSetting.enable_markdown_endpoints = false
    %w[categories tags].each do |directory|
      get "/#{directory}.md"
      expect(response).to have_http_status(:not_found)
      get "/#{directory}", headers: { "ACCEPT" => "text/html" }
      expect(response.headers["Link"]).to be_blank
    end
  end
end
