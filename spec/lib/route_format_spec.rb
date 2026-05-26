# frozen_string_literal: true

RSpec.describe RouteFormat do
  describe ".backup" do
    def full_backup_match?(filename)
      /\A#{described_class.backup}\z/i.match?(filename)
    end

    it "matches valid backup filenames" do
      expect(full_backup_match?("backup-2026-05-12.tar.gz")).to eq(true)
      expect(full_backup_match?("backup-2026-05-12.tgz")).to eq(true)
      expect(full_backup_match?("backup-2026-05-12.sql.gz")).to eq(true)
    end

    it "does not match path traversal attempts" do
      expect(full_backup_match?("../second/backup.tar.gz")).to eq(false)
      expect(full_backup_match?("..%2Fsecond%2Fbackup.tar.gz")).to eq(false)
      expect(full_backup_match?("nested/path/backup.tar.gz")).to eq(false)
    end
  end
end
