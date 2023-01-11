# frozen_string_literal: true

RSpec.describe Imap::Providers::Detector do
  it "returns the gmail provider if the gmail imap server is used" do
    config = {
      server: "imap.gmail.com",
      port: 993,
      ssl: true,
      username: "test@gmail.com",
      password: "testpassword1",
    }
    expect(described_class.init_with_detected_provider(config)).to be_a(Imap::Providers::Gmail)
  end

  it "returns the generic provider if we don't have a special provider defined" do
    config = {
      server: "imap.yo.com",
      port: 993,
      ssl: true,
      username: "test@yo.com",
      password: "testpassword1",
    }
    expect(described_class.init_with_detected_provider(config)).to be_a(Imap::Providers::Generic)
  end
end
