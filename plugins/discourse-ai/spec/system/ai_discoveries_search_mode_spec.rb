# frozen_string_literal: true

describe "AI Discoveries search modes" do
  fab!(:user) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:miyazaki_topic) { Fabricate(:topic, title: "Miyazaki film discussions") }
  fab!(:miyazaki_post) { Fabricate(:post, topic: miyazaki_topic, raw: "Miyazaki films") }
  fab!(:hayao_topic) { Fabricate(:topic, title: "Hayao animation films") }
  fab!(:hayao_post) { Fabricate(:post, topic: hayao_topic, raw: "Hayao films") }

  let(:discoveries_search) { PageObjects::Components::AiDiscoveriesSearch.new }

  before do
    enable_current_plugin
    Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: true)
    assign_fake_provider_to(:ai_default_llm_model)
    assign_agent_to(:ai_ask_ai_agent, [Group::AUTO_GROUPS[:admins]])

    SiteSetting.discourse_ai_enabled = true
    SiteSetting.ai_ask_ai_enabled = true
    SiteSetting.ai_ask_ai_allowed_groups = Group::AUTO_GROUPS[:admins].to_s
    SiteSetting.ai_embeddings_enabled = true
    SiteSetting.ai_embeddings_semantic_search_enabled = true
    SearchIndexer.enable
    SearchIndexer.index(miyazaki_topic, force: true)
    SearchIndexer.index(hayao_topic, force: true)
    sign_in(user)
  end

  after { SearchIndexer.disable }

  it "marks whichever option produced what is on screen" do
    visit "/"
    discoveries_search.open.fill_query("miyazaki")

    expect(discoveries_search).to have_nothing_in_effect

    discoveries_search.select_search

    expect(discoveries_search).to have_search_in_effect
    expect(discoveries_search).to have_topic_result(miyazaki_topic)

    discoveries_search.select_ask

    expect(discoveries_search).to have_ask_in_effect
    expect(discoveries_search).to have_discovery

    discoveries_search.clear_query.select_recent_search("miyazaki")

    expect(discoveries_search).to have_search_in_effect
    expect(discoveries_search).to have_no_discovery
    expect(discoveries_search).to have_topic_result(miyazaki_topic)

    # a different term has to be resubmitted, so nothing answers for it yet
    discoveries_search.fill_query("Hayao")

    expect(discoveries_search).to have_nothing_in_effect

    discoveries_search.submit

    expect(discoveries_search).to have_topic_result(hayao_topic)
    expect(discoveries_search).to have_search_in_effect
    expect(discoveries_search).to have_no_discovery
  end
end
