# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::Grant do
  fab!(:user)

  let(:device_code) { SecureRandom.hex(32) }
  let(:grant) do
    described_class.new(
      status: :pending,
      device_code: device_code,
      scopes: %w[read write],
      unregistered_client: true,
    )
  end

  it "serializes through JSON" do
    parsed = described_class.from_json(grant.to_json)

    expect(parsed).to eq(grant)
    expect(parsed.device_code).to eq(device_code)
  end

  it "transitions grant states" do
    freeze_time

    expect(grant).to be_pending

    grant.assign_codes!(user_code: "ABCD-2345", request_token: "abcdefgh")
    expect(grant.user_code).to eq("ABCD-2345")
    expect(grant.request_token).to eq("abcdefgh")

    grant.authorize!(payload: "encrypted-payload")
    expect(grant).to be_authorized
    expect(grant.payload).to eq("encrypted-payload")
    expect(grant.to_h["authorized_at"]).to eq(Time.zone.now.iso8601)

    denied_grant = described_class.new(status: :pending, device_code: device_code)
    denied_grant.deny!
    expect(denied_grant).to be_denied
    expect(denied_grant.to_h["denied_at"]).to eq(Time.zone.now.iso8601)
  end

  it "binds grants to users" do
    freeze_time
    other_user = Fabricate(:user)

    expect(grant.bind_to_user!(user)).to eq(true)
    expect(grant).to be_authorized_for_user(user)
    expect(grant).to be_bound_to_another_user(other_user)
    expect(grant.to_h["authorizing_username"]).to eq(user.username)
    expect(grant.to_h["authorizing_at"]).to eq(Time.zone.now.iso8601)
    expect(grant.bind_to_user!(other_user)).to eq(false)
  end

  it "builds a grant from request details" do
    freeze_time
    client =
      Fabricate(:user_api_key_client, application_name: "Stored App", public_key: "stored-key")
    params = {
      client_id: client.client_id,
      application_name: "Submitted App",
      public_key: "submitted-key",
      nonce: "nonce",
      push_url: "",
      padding: "oaep",
    }

    grant = described_class.build(params, client, %w[read write], 1.day.to_i, device_code)

    expect(grant).to be_pending
    expect(grant.device_code).to eq(device_code)
    expect(grant.application_name).to eq("Stored App")
    expect(grant.client_id).to eq(client.client_id)
    expect(grant.public_key).to eq(client.public_key)
    expect(grant.nonce).to eq("nonce")
    expect(grant.scopes).to eq(%w[read write])
    expect(grant.push_url).to be_nil
    expect(grant.padding).to eq("oaep")
    expect(grant.expires_in_seconds).to eq(1.day.to_i)
    expect(grant.expires_at).to eq_time(1.day.from_now)
    expect(grant).not_to be_unregistered_client
    expect(grant.to_h["created_at"]).to eq(Time.zone.now.iso8601(6))
  end

  it "builds a grant for an unregistered client" do
    freeze_time
    params = {
      client_id: "unregistered-client",
      application_name: "Submitted App",
      public_key: "submitted-key",
      nonce: "nonce",
      push_url: "https://example.com/push",
      padding: "oaep",
    }

    grant = described_class.build(params, nil, %w[read], nil, device_code)

    expect(grant.application_name).to eq("Submitted App")
    expect(grant.client_id).to eq("unregistered-client")
    expect(grant.public_key).to eq("submitted-key")
    expect(grant.push_url).to eq("https://example.com/push")
    expect(grant).to be_unregistered_client
    expect(grant.to_h["created_at"]).to eq(Time.zone.now.iso8601(6))
  end

  it "falls back to request details when registered client fields are missing" do
    client = UserApiKeyClient.new(client_id: SecureRandom.hex)
    params = {
      client_id: client.client_id,
      application_name: "Submitted App",
      public_key: "submitted-key",
      nonce: "nonce",
    }

    grant = described_class.build(params, client, %w[read], nil, device_code)

    expect(grant.application_name).to eq("Submitted App")
    expect(grant.public_key).to eq("submitted-key")
    expect(grant).to be_unregistered_client
  end

  it "exposes fields used by the authorization view" do
    grant = nil
    freeze_time do
      grant =
        described_class.new(
          status: :pending,
          device_code: device_code,
          user_code: "ABCD-2345",
          application_name: "Device Client",
          client_id: "device-client",
          scopes: %w[read write],
          push_url: "https://example.com/push",
          padding: "oaep",
          expires_in_seconds: 1.day.to_i,
          unregistered_client: true,
        )

      expect(grant.user_code).to eq("ABCD-2345")
      expect(grant.application_name).to eq("Device Client")
      expect(grant.client_id).to eq("device-client")
      expect(grant.localized_scopes).to eq(
        [I18n.t("user_api_key.scopes.read"), I18n.t("user_api_key.scopes.write")],
      )
      expect(grant).to be_write_scope
      expect(grant.push_url).to eq("https://example.com/push")
      expect(grant.padding).to eq("oaep")
      expect(grant.expires_in_seconds).to eq(1.day.to_i)
      expect(grant).to be_unregistered_client
      expect(grant.expires_at).to eq_time(1.day.from_now)
    end

    grant_without_expiry = described_class.new(status: :pending, device_code: device_code)
    expect(grant_without_expiry.expires_at).to be_nil

    grant.scopes = nil
    expect(grant.scopes).to eq([])
    expect(grant).not_to be_write_scope
  end

  it "uses created_at when loading an older serialized grant without expires_at" do
    freeze_time
    grant =
      described_class.new(
        status: :pending,
        device_code: device_code,
        expires_in_seconds: 1.day.to_i,
        created_at: 1.hour.ago.iso8601(6),
      )

    expect(grant.expires_at).to eq_time(23.hours.from_now)
  end

  it "rejects invalid statuses" do
    expect { described_class.new(status: :invalid, device_code: device_code) }.to raise_error(
      ArgumentError,
    )
  end
end
