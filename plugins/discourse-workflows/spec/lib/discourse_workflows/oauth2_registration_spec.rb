# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Registry do
  describe ".oauth2_credential_types" do
    it "registers provider types through the plugin API and prevents disabled providers from executing" do
      provider_type =
        Class.new(DiscourseWorkflows::CredentialTypes::Oauth2ClientCredentials) do
          def self.identifier
            "test_oauth2_provider"
          end
        end
      plugin = Plugin::Instance.new
      plugin.enabled_site_setting(:discourse_sample_plugin_enabled)
      SiteSetting.discourse_sample_plugin_enabled = true
      plugin.register_discourse_workflows_credential_type(provider_type)
      credential =
        Fabricate(:discourse_workflows_oauth2_credential, credential_type: "test_oauth2_provider")

      expect(described_class.oauth2_credential_types).to include(provider_type)
      expect(credential.oauth_provider).to be_a(DiscourseWorkflows::Oauth2Provider)

      node_type = DiscourseWorkflows::Nodes::HttpRequest::V1
      expect(node_type.credentials.first[:credential_types]).to include(provider_type.identifier)
      resolver =
        DiscourseWorkflows::ExpressionResolver.new(
          { "$json" => {} },
          sandbox: DiscourseWorkflows::JsSandbox.new({ "$json" => {} }),
        )
      context =
        DiscourseWorkflows::Executor::NodeExecutionContext.new(
          input_items: [{ "json" => {} }],
          resolver: resolver,
          credentials: {
            "auth" => {
              "id" => credential.id,
            },
          },
          credential_schema: node_type.credentials,
        )

      SiteSetting.discourse_sample_plugin_enabled = false

      expect(described_class.oauth2_credential_types).not_to include(provider_type)
      expect(node_type.credentials.first[:credential_types]).not_to include(
        provider_type.identifier,
      )
      expect {
        context.http_request(
          method: "POST",
          url: "https://api.example.com/contacts",
          options: {
            "authentication" => "test_oauth2_provider",
          },
        )
      }.to raise_error(Discourse::InvalidAccess)
      expect(
        described_class.find_credential_type(
          "test_oauth2_provider",
          include_disabled_plugins: true,
        ),
      ).to eq(provider_type)
      expect {
        DiscourseWorkflows::Oauth2Connection.new(credential).authorization_header(
          "https://api.example.com/contacts",
        )
      }.to raise_error(Discourse::InvalidAccess)
      serialized =
        DiscourseWorkflows::CredentialSerializer
          .new(credential, root: false)
          .as_json
          .deep_stringify_keys
      expect(serialized["data"]["client_secret"]).to eq(
        DiscourseWorkflows::Credential::REDACTED_VALUE,
      )
      expect(serialized["oauth_connection"]).to include("status" => "reconnect_required")
      expect(serialized.to_json).not_to include(credential.oauth_client_secret)
      expect(described_class.find_credential_type("oauth2_client_credentials")).to eq(
        DiscourseWorkflows::CredentialTypes::Oauth2ClientCredentials,
      )
    ensure
      resolver&.dispose
      DiscoursePluginRegistry._raw_discourse_workflows_credential_types.delete_if do |entry|
        entry[:value] == provider_type
      end
    end
  end
end
