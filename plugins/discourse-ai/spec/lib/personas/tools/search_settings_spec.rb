#frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::SearchSettings do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }

  let(:fake_settings) do
    [
      { setting: "default_locale", description: "The default locale for the site", plugin: "core" },
      { setting: "min_post_length", description: "The minimum length of a post", plugin: "core" },
      {
        setting: "ai_bot_enabled",
        description: "Enable or disable the AI bot",
        plugin: "discourse-ai",
      },
      { setting: "min_first_post_length", description: "First post length", plugin: "core" },
    ]
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [llm_model])
  end

  def search_settings(query, mock: true)
    search = described_class.new({ query: query }, bot_user: bot_user, llm: llm)
    search.all_settings = fake_settings if mock
    search
  end

  describe "#process" do
    it "can handle no results" do
      results = search_settings("this will not exist frogs").invoke
      expect(results[:args]).to eq({ query: "this will not exist frogs" })
      expect(results[:rows]).to eq([])
    end

    it "can find a setting based on fuzzy match" do
      results = search_settings("default locale").invoke
      expect(results[:rows].length).to eq(1)
      expect(results[:rows][0][0]).to eq("default_locale")

      results = search_settings("min_post_length").invoke

      expect(results[:rows].length).to eq(2)
      expect(results[:rows][0][0]).to eq("min_post_length")
      expect(results[:rows][1][0]).to eq("min_first_post_length")
    end

    it "can return more many settings with no descriptions if there are lots of hits" do
      results = search_settings("a", mock: false).invoke

      expect(results[:rows].length).to be > 30
      expect(results[:rows][0].length).to eq(1)
    end

    it "can return descriptions if there are few matches" do
      results = search_settings("this will not be found!@,default_locale,ai_bot_enabled").invoke

      expect(results[:rows].length).to eq(2)

      expect(results[:rows][0][1]).not_to eq(nil)
    end
  end
end
