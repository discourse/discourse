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
    it "sanitizes the input and transform the emoji into an img tag" do
      sanitized_label =
        "Test <img src=\"/images/emoji/twitter/+1.png?v=#{Emoji::EMOJI_VERSION}\" title=\"+1\" class=\"emoji\" alt=\"+1\" loading=\"lazy\" width=\"20\" height=\"20\">"
      expect(html).to include(sanitized_label)
    end

    it "sets the data-github-private-repo attr to false" do
      expect(html).to include("data-github-private-repo=\"false\"")
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
end
