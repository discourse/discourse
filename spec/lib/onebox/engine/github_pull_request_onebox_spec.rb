# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubPullRequestOnebox do
  let(:gh_link) { "https://github.com/discourse/discourse/pull/1253/" }
  let(:api_uri) { "https://api.github.com/repos/discourse/discourse/pulls/1253" }
  let(:response) { onebox_response(described_class.onebox_name) }

  before { stub_request(:get, api_uri).to_return(status: 200, body: response) }

  include_context "with engines" do
    let(:link) { gh_link }
  end
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes pull request author" do
      expect(html).to include("jamesaanderson")
    end

    it "includes repository name" do
      expect(html).to include("discourse")
    end

    it "includes branch names" do
      expect(html).to include("<code>main</code> ← <code>jamesaanderson:add-audio-onebox</code>")
    end

    it "includes commit author gravatar" do
      expect(html).to include("b3e9977094ce189bbb493cf7f9adea21")
    end

    it "includes commit time and date" do
      expect(html).to include("02:05AM - 26 Jul 13")
    end

    it "includes number of commits" do
      expect(html).to include("1")
    end

    it "includes number of files changed" do
      expect(html).to include("4")
    end

    it "includes number of additions" do
      expect(html).to include("19")
    end

    it "includes number of deletions" do
      expect(html).to include("5")
    end

    it "includes the body without comments" do
      expect(html).to include("http://meta.discourse.org/t/audio-html5-tag/8168")
      expect(html).not_to include("test comment")
    end

    it "sets the data-github-private-repo attr to false" do
      expect(html).to include("data-github-private-repo=\"false\"")
    end

    context "when the PR is in a private repo" do
      let(:response) do
        resp = MultiJson.load(onebox_response(described_class.onebox_name))
        resp["base"]["repo"]["private"] = true
        MultiJson.dump(resp)
      end

      it "sets the data-github-private-repo attr to true" do
        expect(html).to include("data-github-private-repo=\"true\"")
      end
    end
  end

  context "with commit links" do
    let(:gh_link) do
      "https://github.com/discourse/discourse/pull/1253/commits/d7d3be1130c665cc7fab9f05dbf32335229137a6"
    end
    let(:pr_commit_url) do
      "https://api.github.com/repos/discourse/discourse/commits/d7d3be1130c665cc7fab9f05dbf32335229137a6"
    end

    before do
      stub_request(:get, pr_commit_url).to_return(
        status: 200,
        body: onebox_response(described_class.onebox_name + "_commit"),
      )
    end

    it "includes commit name" do
      doc = Nokogiri.HTML5(html)
      expect(doc.css("h4").text.strip).to eq("Add audio onebox")
      expect(doc.css(".github-body-container").text).to include(
        "http://meta.discourse.org/t/audio-html5-tag/8168",
      )
    end

    context "when github_onebox_access_token is configured" do
      before { SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234" }

      it "sends it as part of the request" do
        html
        expect(WebMock).to have_requested(:get, pr_commit_url).with(
          headers: {
            "Authorization" => "Bearer github_pat_1234",
          },
        )
      end
    end
  end

  context "with comment links" do
    let(:gh_link) { "https://github.com/discourse/discourse/pull/1253/#issuecomment-21597425" }
    let(:comment_api_url) do
      "https://api.github.com/repos/discourse/discourse/issues/comments/21597425"
    end

    before do
      stub_request(:get, comment_api_url).to_return(
        status: 200,
        body: onebox_response(described_class.onebox_name + "_comment"),
      )
    end

    it "includes comment" do
      expect(html).to include("You&#39;ve signed the CLA")
    end

    context "when github_onebox_access_token is configured" do
      before { SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234" }

      it "sends it as part of the request" do
        html
        expect(WebMock).to have_requested(:get, api_uri).with(
          headers: {
            "Authorization" => "Bearer github_pat_1234",
          },
        )
      end
    end
  end

  context "when github_onebox_access_token is configured" do
    before { SiteSetting.github_onebox_access_tokens = "discourse|github_pat_1234" }

    it "sends it as part of the request" do
      html
      expect(WebMock).to have_requested(:get, api_uri).with(
        headers: {
          "Authorization" => "Bearer github_pat_1234",
        },
      )
    end
  end

  describe ".===" do
    it "matches valid GitHub Pull Request URL" do
      valid_url = URI("https://github.com/username/repository/pull/123")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid GitHub Pull Request URL with www" do
      valid_url_with_www = URI("https://www.github.com/username/repository/pull/123")
      expect(described_class === valid_url_with_www).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://github.com.malicious.com/username/repository/pull/123")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match invalid path" do
      invalid_path_url = URI("https://github.com/username/repository/invalid/1234567890abcdef")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end
