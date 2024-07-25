# frozen_string_literal: true

RSpec.describe Onebox::Engine::GithubRepoOnebox do
  let(:gh_link) { "https://github.com/discourse/discourse" }
  let(:api_uri) { "https://api.github.com/repos/discourse/discourse" }
  let(:response) { onebox_response(described_class.onebox_name) }

  before { stub_request(:get, api_uri).to_return(status: 200, body: response) }

  include_context "with engines" do
    let(:link) { gh_link }
  end
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes the description of the repo" do
      expect(html).to include("A platform for community discussion. Free, open, simple.")
    end

    it "includes the name of the repo and truncated description for the title" do
      expect(html).to include(
        "GitHub - discourse/discourse: A platform for community discussion. Free, open,...",
      )
    end

    it "includes a thumbnail url" do
      SecureRandom.stubs(:hex).returns("1234")
      expect(html).to include("https://opengraph.githubassets.com/1234/discourse/discourse")
    end

    it "sets the data-github-private-repo attr to false" do
      expect(html).to include("data-github-private-repo=\"false\"")
    end

    context "when the PR is in a private repo" do
      let(:response) do
        resp = MultiJson.load(onebox_response(described_class.onebox_name))
        resp["private"] = true
        MultiJson.dump(resp)
      end

      it "sets the data-github-private-repo attr to true" do
        expect(html).to include("data-github-private-repo=\"true\"")
      end
    end

    context "when the repo has no description" do
      let(:response) do
        resp = onebox_response(described_class.onebox_name)
        resp["description"] = ""
        resp
      end

      it "includes a message about contributing to the repo" do
        expect(html).to include(I18n.t("onebox.github.no_description", repo: "discourse/discourse"))
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
end
