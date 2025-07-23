#frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::Google do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  let(:progress_blk) { Proc.new {} }
  let(:search) { described_class.new({ query: "some search term" }, bot_user: bot_user, llm: llm) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_google_custom_search_api_key = "abc"
    SiteSetting.ai_google_custom_search_cx = "cx"
  end

  describe "#process" do
    it "will not explode if there are no results" do
      json_text = { searchInformation: { totalResults: "0" } }.to_json

      stub_request(
        :get,
        "https://www.googleapis.com/customsearch/v1?cx=cx&key=abc&num=10&q=some%20search%20term",
      ).to_return(status: 200, body: json_text, headers: {})

      info = search.invoke(&progress_blk).to_json

      expect(search.results_count).to eq(0)
      expect(info).to_not include("oops")
    end

    it "supports base_query" do
      base_query = "site:discourse.org"

      search =
        described_class.new(
          { query: "some search term" },
          bot_user: bot_user,
          llm: llm,
          persona_options: {
            "base_query" => base_query,
          },
        )

      json_text = { searchInformation: { totalResults: "0" } }.to_json

      stub_request(
        :get,
        "https://www.googleapis.com/customsearch/v1?cx=cx&key=abc&num=10&q=site:discourse.org%20some%20search%20term",
      ).to_return(status: 200, body: json_text, headers: {})

      search.invoke(&progress_blk)
    end

    it "can generate correct info" do
      json_text = {
        searchInformation: {
          totalResults: "2",
        },
        items: [
          {
            title: "title1",
            link: "link1",
            snippet: "snippet1",
            displayLink: "displayLink1",
            formattedUrl: "formattedUrl1",
            oops: "do no include me ... oops",
          },
          {
            title: "title2",
            link: "link2",
            displayLink: "displayLink1",
            formattedUrl: "formattedUrl1",
            oops: "do no include me ... oops",
          },
        ],
      }.to_json

      stub_request(
        :get,
        "https://www.googleapis.com/customsearch/v1?cx=cx&key=abc&num=10&q=some%20search%20term",
      ).to_return(status: 200, body: json_text, headers: {})

      info = search.invoke(&progress_blk).to_json

      expect(search.results_count).to eq(2)
      expect(info).to include("title1")
      expect(info).to include("snippet1")
      expect(info).to include("some+search+term")
      expect(info).to include("title2")
      expect(info).to_not include("oops")
    end
  end
end
