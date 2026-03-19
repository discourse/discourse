# frozen_string_literal: true

RSpec.describe DiscourseAi::Mcp::OAuthFlow do
  fab!(:user)
  fab!(:ai_mcp_server) { Fabricate(:ai_mcp_server, auth_type: "oauth") }

  before { enable_current_plugin }

  describe ".start!" do
    it "rejects insecure Discourse site URLs before starting OAuth" do
      Discourse.stubs(:base_url).returns("http://mcp.home.arpa")

      expect { described_class.start!(server: ai_mcp_server, user: user) }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        I18n.t("discourse_ai.mcp_servers.errors.oauth_https_required", url: "http://mcp.home.arpa"),
      )
    end
  end
end
