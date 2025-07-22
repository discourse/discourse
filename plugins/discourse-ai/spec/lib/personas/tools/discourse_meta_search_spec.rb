# frozen_string_literal: true
RSpec.describe DiscourseAi::Personas::Tools::DiscourseMetaSearch do
  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  fab!(:llm_model) { Fabricate(:llm_model, max_prompt_tokens: 8192) }
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  let(:progress_blk) { Proc.new {} }

  let(:mock_search_json) { plugin_file_from_fixtures("search.json", "search_meta").read }

  let(:mock_search_with_categories_json) do
    plugin_file_from_fixtures("search_with_categories.json", "search_meta").read
  end

  let(:mock_site_json) { plugin_file_from_fixtures("site.json", "search_meta").read }

  before do
    stub_request(:get, "https://meta.discourse.org/site.json").to_return(
      status: 200,
      body: mock_site_json,
      headers: {
      },
    )
  end

  it "searches meta.discourse.org" do
    stub_request(:get, "https://meta.discourse.org/search.json?q=test").to_return(
      status: 200,
      body: mock_search_json,
      headers: {
      },
    )

    search = described_class.new({ search_query: "test" }, bot_user: bot_user, llm: llm)
    results = search.invoke(&progress_blk)
    expect(results[:rows].length).to eq(20)

    expect(results[:rows].first[results[:column_names].index("category")]).to eq(
      "documentation > developers",
    )
  end

  it "searches meta.discourse.org with lazy_load_categories enabled" do
    stub_request(:get, "https://meta.discourse.org/search.json?q=test").to_return(
      status: 200,
      body: mock_search_with_categories_json,
      headers: {
      },
    )

    search = described_class.new({ search_query: "test" }, bot_user: bot_user, llm: llm)
    results = search.invoke(&progress_blk)
    expect(results[:rows].length).to eq(20)

    expect(results[:rows].first[results[:column_names].index("category")]).to eq(
      "documentation > developers",
    )
  end

  it "passes on all search parameters" do
    url =
      "https://meta.discourse.org/search.json?q=test%20category:test%20user:test%20order:test%20max_posts:1%20tags:test%20before:test%20after:test%20status:test"

    stub_request(:get, url).to_return(status: 200, body: mock_search_json, headers: {})
    params =
      described_class.signature[:parameters]
        .map do |param|
          if param[:type] == "integer"
            [param[:name], 1]
          else
            [param[:name], "test"]
          end
        end
        .to_h
        .symbolize_keys

    search = described_class.new(params, bot_user: bot_user, llm: llm)
    results = search.invoke(&progress_blk)

    expect(results[:args]).to eq(params)
  end
end
