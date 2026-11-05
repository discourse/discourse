# frozen_string_literal: true

RSpec.describe BackupDownloadResumeWindowSiteSetting do
  describe ".valid_value?" do
    it "accepts known values" do
      expect(described_class.valid_value?(described_class::DISABLED)).to eq(true)
      expect(described_class.valid_value?(described_class::SIX_HOURS)).to eq(true)
    end

    it "rejects unknown values" do
      expect(described_class.valid_value?("forever")).to eq(false)
    end
  end

  describe ".resume_ttl" do
    it "returns zero when resume is disabled" do
      expect(
        described_class.resume_ttl(described_class::DISABLED, email_token_ttl: 1.day.to_i),
      ).to eq(0)
    end

    it "returns the selected resume window when it is shorter than the email token lifetime" do
      expect(
        described_class.resume_ttl(described_class::SIX_HOURS, email_token_ttl: 1.day.to_i),
      ).to eq(6.hours.to_i)
    end

    it "does not outlive the remaining email token lifetime" do
      expect(
        described_class.resume_ttl(described_class::SIX_HOURS, email_token_ttl: 30.minutes.to_i),
      ).to eq(30.minutes.to_i)
    end

    it "uses the full remaining email token lifetime when selected" do
      expect(
        described_class.resume_ttl(
          described_class::UNTIL_EMAIL_TOKEN_EXPIRES,
          email_token_ttl: 3.hours.to_i,
        ),
      ).to eq(3.hours.to_i)
    end

    it "returns zero when the email token has expired" do
      expect(described_class.resume_ttl(described_class::SIX_HOURS, email_token_ttl: 0)).to eq(0)
    end

    it "returns zero for an unknown value" do
      expect(described_class.resume_ttl("forever", email_token_ttl: 1.day.to_i)).to eq(0)
    end
  end
end
