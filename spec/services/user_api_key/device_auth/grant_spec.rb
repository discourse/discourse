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

  it "rejects invalid statuses" do
    expect { described_class.new(status: :invalid, device_code: device_code) }.to raise_error(
      ArgumentError,
    )
  end
end
