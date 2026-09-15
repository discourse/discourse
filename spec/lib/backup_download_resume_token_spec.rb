# frozen_string_literal: true

RSpec.describe BackupDownloadResumeToken do
  let(:user_id) { 123 }
  let(:backup_filename) { "example-2026-08-31.tar.gz" }
  let(:other_backup_filename) { "other-2026-08-31.tar.gz" }
  let(:token) { "secret-token" }

  describe ".set and .compare" do
    it "stores a token for the same user and backup" do
      described_class.set(user_id, backup_filename, token, ttl: 1.hour)

      expect(described_class.compare(user_id, backup_filename, token)).to eq(true)
    end

    it "does not authorize a different backup" do
      described_class.set(user_id, backup_filename, token, ttl: 1.hour)

      expect(described_class.compare(user_id, other_backup_filename, token)).to eq(false)
    end

    it "does not authorize a different user" do
      described_class.set(user_id, backup_filename, token, ttl: 1.hour)

      expect(described_class.compare(user_id + 1, backup_filename, token)).to eq(false)
    end

    it "does not store a token with a non-positive ttl" do
      described_class.set(user_id, backup_filename, token, ttl: 0)

      expect(described_class.compare(user_id, backup_filename, token)).to eq(false)
    end

    it "sets the requested expiry" do
      described_class.set(user_id, backup_filename, token, ttl: 1.hour)

      ttl = Discourse.redis.ttl(described_class.key(user_id, backup_filename))

      expect(ttl).to be_between(1.hour.to_i - 2, 1.hour.to_i)
    end
  end
end
