# frozen_string_literal: true

describe DiscourseAi::Discoveries::ExternalSource do
  fab!(:user)

  before { enable_current_plugin }

  describe ".normalize" do
    it "keeps the shared fields as plain text and drops malformed results" do
      results =
        described_class.normalize(
          [
            {
              "title" => "<b>Configuring</b> SSO",
              "url" => "https://kb.example.com/sso",
              "blurb" => "How to set up <i>SAML</i>",
              "content" => "Step one",
              "published_at" => "2026-09-01T10:00:00+02:00",
              "rating" => 5,
            },
            { "title" => "Script link", "url" => "javascript:alert(1)" },
            { "title" => "Relative link", "url" => "/sso" },
            { "url" => "https://kb.example.com/untitled" },
            "bare string",
            { "title" => "Undated", "url" => "http://kb.example.com/a", "published_at" => "soon" },
          ],
        )

      expect(results).to eq(
        [
          {
            "title" => "Configuring SSO",
            "url" => "https://kb.example.com/sso",
            "blurb" => "How to set up SAML",
            "content" => "Step one",
            "published_at" => "2026-09-01T08:00:00Z",
          },
          { "title" => "Undated", "url" => "http://kb.example.com/a" },
        ],
      )
    end

    it "truncates long fields and caps the number of results" do
      output =
        Array.new(described_class::MAX_RESULTS + 1) do |index|
          { "title" => "t" * 500, "url" => "https://kb.example.com/#{index}", "blurb" => "b" * 500 }
        end

      results = described_class.normalize(output)

      expect(results.length).to eq(described_class::MAX_RESULTS)
      expect(results.first["title"].length).to eq(described_class::TITLE_LIMIT)
      expect(results.first["blurb"].length).to eq(described_class::BLURB_LIMIT)
    end

    it "raises when the output is not a list" do
      expect { described_class.normalize({ "results" => [] }) }.to raise_error(
        described_class::InvalidResults,
      )
    end

    it "raises on the first malformed result in strict mode" do
      expect {
        described_class.normalize(
          [{ "title" => "Good", "url" => "https://kb.example.com" }, { "title" => "Bad" }],
          strict: true,
        )
      }.to raise_error(described_class::InvalidResults, /2/)
    end
  end

  describe "#call" do
    it "invokes the tool with the queries and returns its results as candidates" do
      ai_tool = Fabricate(:ai_tool, name: "Help center", script: <<~JS)
            function invoke(params) {
              return [{
                title: params.keyword_query + " in " + params.locale,
                url: "https://kb.example.com/a",
                blurb: "Short",
                content: "Long",
              }];
            }
          JS

      candidates =
        described_class.new(ai_tool, user:).call(
          query: "how do I reset my password",
          keyword_query: "reset password",
          semantic_query: "How can I reset a forgotten password?",
          locale: "en",
        )

      expect(candidates).to eq(
        [
          {
            "kind" => "external",
            "source_id" => ai_tool.id,
            "source_name" => "Help center",
            "title" => "reset password in en",
            "url" => "https://kb.example.com/a",
            "blurb" => "Short",
            "excerpt" => "Long",
          },
        ],
      )
    end

    it "gives configured tools the model that writes the answer" do
      SiteSetting.ai_ask_ai_agent =
        Fabricate(:ai_agent, default_llm_id: Fabricate(:llm_model).id).id
      ai_tool = Fabricate(:ai_tool, script: <<~JS)
        function invoke() {
          return [{ title: llm.truncate("one two three four", 2), url: "https://kb.example.com/a" }];
        }
      JS
      SiteSetting.ai_ask_ai_external_sources = ai_tool.id.to_s

      candidates =
        described_class
          .configured(user:)
          .first
          .call(query: "q", keyword_query: "q", semantic_query: "q", locale: "en")

      expect(candidates.first["title"]).to be_present
      expect(candidates.first["title"]).not_to include("four")
    end

    it "raises when the tool fails" do
      ai_tool = Fabricate(:ai_tool, script: "function invoke() { throw new Error('down'); }")

      expect {
        described_class.new(ai_tool, user:).call(
          query: "q",
          keyword_query: "q",
          semantic_query: "q",
          locale: "en",
        )
      }.to raise_error(StandardError)
    end
  end
end
