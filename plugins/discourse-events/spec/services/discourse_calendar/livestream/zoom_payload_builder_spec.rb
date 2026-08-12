# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Livestream::ZoomPayloadBuilder do
  subject(:payload) { described_class.call(topic:, user:, zoom_join_data:) }

  fab!(:user)
  fab!(:topic)

  let(:zoom_join_data) do
    { meeting_number: "123456789", password: "secret", url: "https://zoom.us/j/123456789" }
  end

  before do
    SiteSetting.livestream_zoom_sdk_key = "sdk-key"
    SiteSetting.livestream_zoom_sdk_secret = "sdk-secret"
  end

  def decoded_signature
    JWT.decode(
      payload[:signature],
      SiteSetting.livestream_zoom_sdk_secret,
      true,
      algorithm: "HS256",
    )[
      0
    ]
  end

  it "returns everything the Meeting SDK needs to join" do
    expect(payload).to include(
      sdk_key: "sdk-key",
      meeting_number: "123456789",
      password: "secret",
      user_name: user.display_name,
      user_email: user.email,
      leave_url: topic.relative_url,
    )
  end

  it "signs the payload with the configured SDK secret" do
    expect {
      JWT.decode(payload[:signature], "wrong-secret", true, algorithm: "HS256")
    }.to raise_error(JWT::VerificationError)
    expect(decoded_signature).to be_present
  end

  it "signs the user in as a participant, never as the host" do
    expect(decoded_signature["role"]).to eq(described_class::ROLE_PARTICIPANT)
    expect(decoded_signature["role"]).to eq(0)
  end

  it "signs the meeting number the user is joining" do
    expect(decoded_signature["mn"]).to eq("123456789")
    expect(decoded_signature["sdkKey"]).to eq("sdk-key")
    expect(decoded_signature["appKey"]).to eq("sdk-key")
  end

  it "backdates the issued-at claim so a skewed client clock still accepts the token" do
    freeze_time

    expect(decoded_signature["iat"]).to eq(
      Time.zone.now.to_i - described_class::TOKEN_ISSUE_LEEWAY.to_i,
    )
  end

  it "expires the token two hours after it was issued" do
    freeze_time

    expected =
      Time.zone.now.to_i - described_class::TOKEN_ISSUE_LEEWAY.to_i +
        described_class::TOKEN_VALIDITY.to_i

    expect(decoded_signature["exp"]).to eq(expected)
    expect(decoded_signature["tokenExp"]).to eq(expected)
  end

  context "when the meeting has no password" do
    let(:zoom_join_data) do
      { meeting_number: "123456789", password: nil, url: "https://zoom.us/j/123456789" }
    end

    it "returns a nil password rather than omitting it" do
      expect(payload).to include(password: nil)
    end
  end
end
