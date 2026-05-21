# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::GrantPresenter do
  subject(:presenter) { described_class.new(grant) }

  let(:grant) do
    UserApiKey::DeviceAuth::Grant.new(
      status: :pending,
      device_code: SecureRandom.hex(32),
      user_code: "ABCD-2345",
      application_name: "Device Client",
      client_id: "device-client",
      scopes: %w[read write],
      push_url: "https://example.com/push",
      padding: "oaep",
      expires_in_seconds: 1.day.to_i,
      unregistered_client: true,
    )
  end

  it "exposes grant fields used by the authorization view" do
    expect(presenter.device_code).to eq(grant.device_code)
    expect(presenter.user_code).to eq("ABCD-2345")
    expect(presenter.application_name).to eq("Device Client")
    expect(presenter.client_id).to eq("device-client")
    expect(presenter.scopes).to eq(%w[read write])
    expect(presenter.scopes_csv).to eq("read,write")
    expect(presenter.push_url).to eq("https://example.com/push")
    expect(presenter.padding).to eq("oaep")
    expect(presenter.expires_in_seconds).to eq(1.day.to_i)
  end

  it "localizes scopes" do
    expect(presenter.localized_scopes).to eq(
      [I18n.t("user_api_key.scopes.read"), I18n.t("user_api_key.scopes.write")],
    )
  end

  it "detects write scope" do
    expect(presenter).to be_write_scope
  end

  it "detects unregistered clients" do
    expect(presenter).to be_unregistered_client
  end

  it "calculates the expiry time" do
    freeze_time { expect(presenter.expires_at).to eq_time(1.day.from_now) }
  end

  context "without an expiry" do
    before { grant.expires_in_seconds = nil }

    it "returns nil" do
      expect(presenter.expires_at).to be_nil
    end
  end

  context "without scopes" do
    before { grant.scopes = nil }

    it "handles missing scopes" do
      expect(presenter.scopes).to eq([])
      expect(presenter.scopes_csv).to eq("")
      expect(presenter).not_to be_write_scope
    end
  end
end
