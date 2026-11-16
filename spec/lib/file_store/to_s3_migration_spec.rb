# frozen_string_literal: true

RSpec.describe FileStore::ToS3Migration do
  describe "#migrate" do
    let(:root) { Dir.mktmpdir }
    let(:public_dir) { File.join(root, "public") }
    let(:upload_dir) { File.join(public_dir, "uploads", "default", "original", "1X") }
    let(:fake_s3) { FakeS3.create }

    before do
      setup_s3
      Rails.stubs(:public_path).returns(Pathname.new(public_dir))
      described_class.any_instance.stubs(:uploads_migrated_to_new_scheme?).returns(true)
      described_class.any_instance.stubs(:migration_successful?).returns(true)
      s3_client = fake_s3.s3_client
      Aws::S3::Client.stubs(:new).returns(s3_client)
    end

    after { FileUtils.rm_rf(root) }

    def migrate
      silence_stdout do
        described_class.new(s3_options: { bucket: SiteSetting.s3_upload_bucket }).migrate
      end
    end

    it "does not split file names on newlines" do
      FileUtils.mkdir_p(upload_dir)
      File.write(File.join(upload_dir, "a\nb.png"), "b")

      migrate

      expect(
        fake_s3.bucket(SiteSetting.s3_upload_bucket).find_object("original/1X/a\nb.png"),
      ).to be_present
    end
  end
end
