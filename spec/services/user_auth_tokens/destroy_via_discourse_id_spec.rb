# frozen_string_literal: true

RSpec.describe UserAuthToken::DestroyViaDiscourseId do
  subject(:result) { described_class.call(params: params) }

  let(:client_id) { SiteSetting.discourse_id_client_id }
  let(:hashed_secret) { Digest::SHA256.hexdigest(SiteSetting.discourse_id_client_secret) }
  let(:identifier) { SecureRandom.hex }
  let(:provider_name) { "discourse_id" }

  let!(:user) { Fabricate(:user) }
  let!(:uaa) do
    Fabricate(
      :user_associated_account,
      user:,
      provider_name: "discourse_id",
      provider_uid: identifier,
    )
  end
  let(:timestamp) { Time.now.to_i }
  let(:signature) do
    OpenSSL::HMAC.hexdigest("sha256", hashed_secret, "#{client_id}:#{identifier}:#{timestamp}")
  end

  before do
    SiteSetting.enable_discourse_id = true
    SiteSetting.discourse_id_client_id = SecureRandom.hex
    SiteSetting.discourse_id_client_secret = SecureRandom.hex
  end

  let(:params) { { identifier: uaa.provider_uid, timestamp: timestamp, signature: signature } }

  it "destroys user auth tokens when all validations pass" do
    UserAuthToken.generate!(user_id: user.id)

    expect(UserAuthToken.where(user_id: user.id).count).to eq(1)

    expect { result }.to change { UserAuthToken.where(user_id: user.id).count }.from(1).to(0)
    expect(result).to run_successfully
  end

  it "fails if timestamp is expired" do
    params[:timestamp] = (Time.now - 10.minutes).to_i
    expect(result.success?).to eq(false)
    expect(result).to fail_a_step(:validate_timestamp)
  end

  it "fails if discourse id is not enabled" do
    SiteSetting.enable_discourse_id = false
    expect(result.success?).to eq(false)
    expect(result).to fail_a_step(:validate_discourse_id)
  end

  it "fails if client id is missing" do
    SiteSetting.discourse_id_client_id = ""
    expect(result.success?).to eq(false)
    expect(result).to fail_a_step(:validate_discourse_id)
  end

  it "fails if client secret is missing" do
    SiteSetting.discourse_id_client_secret = ""
    expect(result.success?).to eq(false)
    expect(result).to fail_a_step(:validate_discourse_id)
  end

  it "fails if signature is invalid" do
    params[:signature] = "invalid"
    expect(result.success?).to eq(false)
    expect(result).to fail_a_step(:validate_signature)
  end

  it "fails if user is not found" do
    params[:identifier] = "notfound"
    expect(result.success?).to eq(false)
  end
end
