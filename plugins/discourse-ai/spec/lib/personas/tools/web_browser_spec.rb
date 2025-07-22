# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::WebBrowser do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#invoke" do
    it "can retrieve the content of a webpage and returns the processed text" do
      url = "https://arxiv.org/html/2403.17011v1"
      processed_text = "This is a simplified version of the webpage content."

      # Mocking the web request to return a specific HTML structure
      stub_request(:get, url).to_return(
        status: 200,
        body:
          "<html><head><title>Test</title></head><body><p>This is a simplified version of the webpage content.</p></body></html>",
      )

      tool = described_class.new({ url: url }, bot_user: bot_user, llm: llm)
      result = tool.invoke

      expect(result).to have_key(:text)
      expect(result[:text]).to eq(processed_text)
      expect(result[:url]).to eq(url)
    end

    it "returns an error if the webpage cannot be retrieved" do
      url = "https://arxiv.org/html/2403.17011v1"

      # Simulating a failed request
      stub_request(:get, url).to_return(status: [500, "Internal Server Error"])

      tool = described_class.new({ url: url }, bot_user: bot_user, llm: llm)
      result = tool.invoke

      expect(result).to have_key(:error)
      expect(result[:error]).to include("Failed to retrieve the web page")
    end
  end

  describe "#invoke with various HTML structures" do
    let(:url) { "http://example.com" }

    it "extracts main content from a simple HTML structure" do
      simple_html = "<html><body><p>Simple content.</p></body></html>"
      stub_request(:get, url).to_return(status: 200, body: simple_html)

      tool = described_class.new({ url: url }, bot_user: bot_user, llm: llm)
      result = tool.invoke

      expect(result[:text]).to eq("Simple content.")
    end

    it "correctly ignores script and style tags" do
      complex_html =
        "<html><head><script>console.log('Ignore me')</script></head><body><style>body { background-color: #000; }</style><p>Only relevant content here.</p></body></html>"
      stub_request(:get, url).to_return(status: 200, body: complex_html)

      tool = described_class.new({ url: url }, bot_user: bot_user, llm: llm)
      result = tool.invoke

      expect(result[:text]).to eq("Only relevant content here.")
    end

    it "extracts content from nested structures" do
      nested_html =
        "<html><body><div><section><p>Nested paragraph 1.</p></section><section><p>Nested paragraph 2.</p></section></div></body></html>"
      stub_request(:get, url).to_return(status: 200, body: nested_html)

      tool = described_class.new({ url: url }, bot_user: bot_user, llm: llm)
      result = tool.invoke

      expect(result[:text]).to eq("Nested paragraph 1. Nested paragraph 2.")
    end
  end

  describe "#invoke with redirects" do
    let(:initial_url) { "http://initial-example.com" }
    let(:final_url) { "http://final-example.com" }
    let(:redirect_html) { "<html><body><p>Redirected content.</p></body></html>" }

    it "follows redirects and retrieves content from the final destination" do
      stub_request(:get, initial_url).to_return(status: 302, headers: { "Location" => final_url })
      stub_request(:get, final_url).to_return(status: 200, body: redirect_html)

      tool = described_class.new({ url: initial_url }, bot_user: bot_user, llm: llm)
      result = tool.invoke

      expect(result[:url]).to eq(final_url)
      expect(result[:text]).to eq("Redirected content.")
    end
  end
end
