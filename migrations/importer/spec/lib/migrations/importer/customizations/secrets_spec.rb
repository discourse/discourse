# frozen_string_literal: true

require "stringio"

RSpec.describe Migrations::Importer::Customizations::Secrets do
  let(:output) { StringIO.new }

  it "recognizes secret-looking setting names" do
    expect(described_class.secret_name?("openid_connect_client_secret")).to be(true)
    expect(described_class.secret_name?("some_api_key")).to be(true)
    expect(described_class.secret_name?("title")).to be(false)
    expect(described_class.secret_name?("discourse_connect_provider_secrets")).to be(true)
    expect(described_class.secret_name?("github_onebox_access_tokens")).to be(true)
    expect(described_class.secret_name?("chat_integration_slack_outbound_webhook_url")).to be(true)
  end

  it "doesn't treat settings about secrets as secret" do
    %w[
      min_password_length
      block_common_passwords
      revoke_api_keys_unused_days
      user_api_key_allowed_groups
      email_token_valid_hours
      ai_strict_token_counting
      hcaptcha_site_key
      voice_turn_secret_servers
    ].each { |name| expect(described_class.secret_name?(name)).to be(false), name }
  end

  it "recognizes credential columns" do
    expect(described_class.secret_column?("users", "password_hash")).to be(true)
    expect(described_class.secret_column?("api_keys", "key_hash")).to be(true)
    expect(described_class.secret_column?("user_second_factors", "data")).to be(true)
    expect(described_class.secret_column?("themes", "data")).to be(false)
    expect(described_class.secret_column?("users", "username")).to be(false)
  end

  it "reads settings flagged as secret from the settings files" do
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "config"))
      FileUtils.mkdir_p(File.join(root, "plugins", "chat", "config"))
      File.write(File.join(root, "config", "site_settings.yml"), <<~YAML)
        login:
          some_client_id:
            default: ""
            secret: true
          title:
            default: ""
      YAML
      File.write(File.join(root, "plugins", "chat", "config", "settings.yml"), <<~YAML)
        plugins:
          chat_webhook:
            secret: true
      YAML

      expect(described_class.flagged_setting_names(root, warnings: output)).to eq(
        Set["some_client_id", "chat_webhook"],
      )
    end
  end

  it "reads the value from the environment" do
    secrets =
      described_class.new(
        env: {
          "DISCO_SECRET_OIDC_SECRET" => "s3cret",
        },
        input: StringIO.new,
        output:,
      )
    expect(secrets.fetch("oidc_secret")).to eq("s3cret")
  end

  it "returns nil without a TTY when the environment has no value" do
    secrets = described_class.new(env: {}, input: StringIO.new("typed\n"), output:)
    expect(secrets.fetch("oidc_secret")).to be_nil
  end

  it "prompts without echo on a TTY" do
    input = StringIO.new("typed\n")
    input.define_singleton_method(:tty?) { true }
    input.define_singleton_method(:noecho) { |&block| block.call(self) }

    secrets = described_class.new(env: {}, input:, output:)

    expect(secrets.fetch("oidc_secret")).to eq("typed")
    expect(output.string).to include("oidc_secret")
  end
end
