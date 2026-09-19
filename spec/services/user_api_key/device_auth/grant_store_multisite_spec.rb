# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::GrantStore, type: :multisite do
  let(:device_code) { SecureRandom.hex(32) }

  after { clear_user_api_key_device_auth_redis! }

  it "keeps grants with the same device code isolated by site" do
    default_grant = UserApiKey::DeviceAuth::Grant.new(status: :pending, device_code: device_code)
    second_grant = UserApiKey::DeviceAuth::Grant.new(status: :denied, device_code: device_code)

    described_class.save!(default_grant, ttl: 1.minute)

    test_multisite_connection("second") do
      described_class.save!(second_grant, ttl: 1.minute)
      expect(described_class.load(device_code)).to eq(second_grant)
      described_class.clear!
      expect(described_class.load(device_code)).to be_nil
    end

    expect(described_class.load(device_code)).to eq(default_grant)
  end

  it "releases the original site's lock even if the current connection changes" do
    original_db = RailsMultisite::ConnectionManagement.current_db

    described_class.with_lock!(device_code) do
      RailsMultisite::ConnectionManagement.establish_connection(db: "second")
    end

    RailsMultisite::ConnectionManagement.establish_connection(db: original_db)
    expect(Discourse.redis.get(described_class.lock_key(device_code))).to be_nil
  ensure
    RailsMultisite::ConnectionManagement.establish_connection(db: original_db) if original_db
  end
end
