# frozen_string_literal: true

describe McpOauthClient do
  it "accepts an IPv6 loopback redirect URI" do
    expect(described_class.valid_redirect_uri?("http://[::1]/callback")).to eq(true)
  end

  describe "#allows_redirect_uri?" do
    it "allows a different port for a registered loopback IP redirect" do
      client =
        McpOauthClient.new(
          redirect_uris: [
            "http://127.0.0.1/callback?source=codex",
            "http://[::1]/callback?source=codex",
          ],
        )

      expect(
        [
          client.allows_redirect_uri?("http://127.0.0.1:49152/callback?source=codex"),
          client.allows_redirect_uri?("http://[::1]:49153/callback?source=codex"),
        ],
      ).to all(be(true))
    end

    it "does not relax other redirect URI components or non-IP hosts" do
      client =
        McpOauthClient.new(
          redirect_uris: %w[
            http://127.0.0.1/callback?source=codex
            http://localhost/callback
            https://client.example.com/callback
          ],
        )

      expect(
        [
          client.allows_redirect_uri?("http://127.0.0.1:49152/other?source=codex"),
          client.allows_redirect_uri?("http://127.0.0.1:49152/callback?source=other"),
          client.allows_redirect_uri?("http://localhost:49152/callback"),
          client.allows_redirect_uri?("https://client.example.com:49152/callback"),
        ],
      ).to all(be(false))
    end
  end
end
