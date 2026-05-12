# frozen_string_literal: true

RSpec.describe BrowserPageviewEvent do
  it "truncates string fields before saving" do
    event =
      described_class.create!(
        url: "a" * (described_class::MAX_URL_LENGTH + 1),
        referrer: "a" * (described_class::MAX_REFERRER_LENGTH + 1),
        user_agent: "a" * (described_class::MAX_USER_AGENT_LENGTH + 1),
        ip_address: "1.2.3.4",
        session_id: "a" * (described_class::MAX_SESSION_ID_LENGTH + 1),
      )

    expect(event.url.length).to eq(described_class::MAX_URL_LENGTH)
    expect(event.referrer.length).to eq(described_class::MAX_REFERRER_LENGTH)
    expect(event.user_agent.length).to eq(described_class::MAX_USER_AGENT_LENGTH)
    expect(event.session_id.length).to eq(described_class::MAX_SESSION_ID_LENGTH)
  end
end
