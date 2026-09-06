# frozen_string_literal: true

RSpec.describe Onebox::GithubAccess do
  before { Discourse::GithubApi.reset_clients! }

  describe ".token" do
    it "returns nil when no onebox tokens are configured" do
      SiteSetting.github_onebox_access_tokens = ""
      expect(described_class.token("discourse")).to be_nil
    end

    it "resolves the per-org token, falling back to the default mapping" do
      SiteSetting.github_onebox_access_tokens = "discourse|org_tok\ndefault|def_tok"
      expect(described_class.token("discourse")).to eq("org_tok")
      expect(described_class.token("someoneelse")).to eq("def_tok")
    end

    it "returns nil for an unmapped org when no default is configured" do
      SiteSetting.github_onebox_access_tokens = "discourse|org_tok"
      expect(described_class.token("someoneelse")).to be_nil
    end
  end

  describe ".tokens" do
    it "returns just the unauthenticated identity when nothing is configured" do
      SiteSetting.github_onebox_access_tokens = ""
      expect(described_class.tokens).to eq([nil])
    end

    it "returns every configured token plus the unauthenticated identity" do
      SiteSetting.github_onebox_access_tokens = "discourse|org_tok\ndefault|def_tok"
      expect(described_class.tokens).to contain_exactly("org_tok", "def_tok", nil)
    end
  end

  describe ".client" do
    it "builds a client authenticated with the org's onebox token" do
      SiteSetting.github_onebox_access_tokens = "discourse|org_tok\ndefault|def_tok"

      org_stub =
        stub_request(:get, "https://api.github.com/x").with(
          headers: {
            "Authorization" => "Bearer org_tok",
          },
        ).to_return(status: 200, body: "{}")
      described_class.client("discourse").get("/x")
      expect(org_stub).to have_been_requested

      default_stub =
        stub_request(:get, "https://api.github.com/y").with(
          headers: {
            "Authorization" => "Bearer def_tok",
          },
        ).to_return(status: 200, body: "{}")
      described_class.client("someoneelse").get("/y")
      expect(default_stub).to have_been_requested
    end

    it "builds an unauthenticated client when no onebox token is configured" do
      SiteSetting.github_onebox_access_tokens = ""

      stub =
        stub_request(:get, "https://api.github.com/z")
          .with { |request| !request.headers.key?("Authorization") }
          .to_return(status: 200, body: "{}")
      described_class.client("discourse").get("/z")
      expect(stub).to have_been_requested
    end
  end
end
