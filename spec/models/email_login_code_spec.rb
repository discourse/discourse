# frozen_string_literal: true

RSpec.describe EmailLoginCode do
  describe ".generate!" do
    it "creates a record with a hashed 6-digit code" do
      record = described_class.generate!(email: "foo@example.com")

      expect(record).to be_persisted
      expect(record.code).to match(/\A\d{6}\z/)
      expect(record.code_hash).to eq(described_class.hash_code(record.code))
    end

    it "downcases the email" do
      record = described_class.generate!(email: "FoO@ExAmPlE.cOm")

      expect(record.email).to eq("foo@example.com")
    end

    it "deletes prior codes for the same email case-insensitively" do
      old_record = described_class.generate!(email: "FOO@example.com")
      other_record = described_class.generate!(email: "bar@example.com")

      new_record = described_class.generate!(email: "foo@example.com")

      expect(described_class.all).to contain_exactly(other_record, new_record)
    end

    it "expires the code after 10 minutes" do
      freeze_time

      record = described_class.generate!(email: "foo@example.com")

      expect(record.expires_at).to eq_time(described_class::VALID_FOR.from_now)
    end

    it "does not expose the plaintext code on a re-fetched instance" do
      described_class.generate!(email: "foo@example.com")

      expect { described_class.last.code }.to raise_error(described_class::CodeAccessError)
    end
  end

  describe ".active" do
    fab!(:login_code) { EmailLoginCode.generate!(email: "foo@example.com") }

    it "includes fresh codes" do
      expect(described_class.active).to contain_exactly(login_code)
    end

    it "excludes consumed codes" do
      login_code.consume!

      expect(described_class.active).to be_empty
    end

    it "excludes expired codes" do
      login_code.update!(expires_at: 1.minute.ago)

      expect(described_class.active).to be_empty
    end

    it "excludes locked out codes" do
      login_code.update!(attempts: described_class::MAX_ATTEMPTS)

      expect(described_class.active).to be_empty
    end
  end

  describe ".for_email" do
    fab!(:login_code) { EmailLoginCode.generate!(email: "foo@example.com") }

    it "matches case-insensitively" do
      expect(described_class.for_email("FOO@EXAMPLE.COM")).to contain_exactly(login_code)
      expect(described_class.for_email("bar@example.com")).to be_empty
    end
  end

  describe "#verify" do
    let(:login_code) { EmailLoginCode.generate!(email: "foo@example.com") }
    let(:code) { login_code.code }
    let(:wrong_code) { code == "000000" ? "000001" : "000000" }

    it "returns false for a wrong code and burns an attempt" do
      expect(login_code.verify(wrong_code)).to eq(false)
      expect(login_code.reload.attempts).to eq(1)
    end

    it "returns true for the correct code and resets attempts" do
      login_code.verify(wrong_code)

      expect(login_code.verify(code)).to eq(true)
      expect(login_code.reload.attempts).to eq(0)
    end

    it "locks out after max attempts even with the correct code" do
      described_class::MAX_ATTEMPTS.times { login_code.verify(wrong_code) }

      expect(login_code.verify(code)).to eq(false)
      expect(login_code.reload.attempts).to eq(described_class::MAX_ATTEMPTS)
    end

    it "returns false for a consumed code without burning attempts" do
      login_code.consume!

      expect(login_code.verify(code)).to eq(false)
      expect(login_code.reload.attempts).to eq(0)
    end

    it "returns false for an expired code without burning attempts" do
      login_code.update!(expires_at: 1.minute.ago)

      expect(login_code.verify(code)).to eq(false)
      expect(login_code.reload.attempts).to eq(0)
    end
  end

  describe "#consume!" do
    fab!(:login_code) { EmailLoginCode.generate!(email: "foo@example.com") }

    it "marks the code as consumed" do
      freeze_time

      login_code.consume!

      expect(login_code.reload.consumed_at).to eq_time(Time.zone.now)
    end

    it "only succeeds once, so concurrent redemptions can't both win" do
      expect(login_code.consume!).to eq(true)
      # a second caller holding the same (stale) record loses the race
      expect(login_code.consume!).to eq(false)
    end
  end

  describe ".hash_code" do
    it "keys the hash with the server secret rather than a bare digest" do
      hash = described_class.hash_code("123456")

      expect(hash).not_to eq(Digest::SHA256.hexdigest("123456"))
      expect(hash).to eq(
        OpenSSL::HMAC.hexdigest("SHA256", GlobalSetting.safe_secret_key_base, "123456"),
      )
    end
  end
end
