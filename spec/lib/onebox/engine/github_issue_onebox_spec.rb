# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubIssueOnebox do
  let(:issue_uri) { "https://api.github.com/repos/discourse/discourse/issues/1" }
  let(:repo_uri) { "https://api.github.com/repos/discourse/discourse" }
  let(:repo_response) { onebox_response("githubrepo") }

  before do
    stub_request(:get, issue_uri).to_return(
      status: 200,
      body: onebox_response("github_issue_onebox"),
    )
    stub_request(:get, repo_uri).to_return(status: 200, body: repo_response)
  end

  include_context "with engines" do
    let(:link) { "https://github.com/discourse/discourse/issues/1" }
  end
  it_behaves_like "an engine"

  describe "#to_html" do
    it "shows the preview type and repository in the header" do
      header = Nokogiri::HTML5.fragment(html).at_css("aside > header")

      expect(header.at_css(".github-onebox__label").text.strip).to eq("Open issue")
      expect(header.at_css("a").text.strip).to eq("discourse/discourse")
      expect(header.at_css("a")["href"]).to eq(link)
    end

    it "sanitizes the input and transform the emoji into an img tag" do
      sanitized_label =
        "Test <img src=\"/images/emoji/twitter/+1.png?v=#{Emoji::EMOJI_VERSION}\" title=\"+1\" class=\"emoji\" alt=\"+1\" loading=\"lazy\" width=\"20\" height=\"20\">"
      expect(html).to include(sanitized_label)
    end

    it "sets the data-github-private-repo attr to false" do
      expect(html).to include("data-github-private-repo=\"false\"")
    end

    it "shows a closed issue header when the issue has been closed" do
      response = MultiJson.load(onebox_response("github_issue_onebox"))
      response["closed_at"] = "2026-10-15T06:00:00Z"
      response["closed_by"] = response["user"]
      stub_request(:get, issue_uri).to_return(body: MultiJson.dump(response))

      preview = Nokogiri::HTML5.fragment(html)

      expect(preview.at_css(".github-onebox__label").text.strip).to eq("Closed issue")
    end

    context "when the PR is in a private repo" do
      let(:repo_response) do
        resp = MultiJson.load(onebox_response("githubrepo"))
        resp["private"] = true
        MultiJson.dump(resp)
      end

      it "sets the data-github-private-repo attr to true" do
        expect(html).to include("data-github-private-repo=\"true\"")
      end
    end

    context "when github_onebox_access_token is configured" do
      before { SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234" }

      it "sends it as part of the request" do
        html
        expect(WebMock).to have_requested(:get, issue_uri).with(
          headers: {
            "Authorization" => "Bearer github_pat_1234",
          },
        )
      end
    end
  end

  describe "#inline_data" do
    let(:link) { "https://github.com/discourse/discourse/issues/1" }

    it "returns nil when no access token is configured" do
      expect(described_class.new(link).inline_data).to be_nil
    end

    it "returns the issue title from the API when an access token is configured" do
      SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234"
      expect(described_class.new(link).inline_data).to eq(
        title: "Test issue #2 - Issue #1 - discourse/discourse - GitHub",
      )
    end
  end
end
