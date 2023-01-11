# frozen_string_literal: true

RSpec.describe ExternalUploadManager do
  fab!(:user) { Fabricate(:user) }
  let!(:logo_file) { file_from_fixtures("logo.png") }
  let!(:pdf_file) { file_from_fixtures("large.pdf", "pdf") }
  let(:object_size) { 1.megabyte }
  let(:etag) { "e696d20564859cbdf77b0f51cbae999a" }
  let(:client_sha1) { Upload.generate_digest(object_file) }
  let(:sha1) { Upload.generate_digest(object_file) }
  let(:object_file) { logo_file }
  let(:external_upload_stub_metadata) { {} }
  let!(:external_upload_stub) { Fabricate(:image_external_upload_stub, created_by: user) }
  let(:s3_bucket_name) { SiteSetting.s3_upload_bucket }

  subject { ExternalUploadManager.new(external_upload_stub) }

  before do
    SiteSetting.authorized_extensions += "|pdf"
    SiteSetting.max_attachment_size_kb = 210.megabytes / 1000

    setup_s3

    SiteSetting.s3_backup_bucket = "s3-backup-bucket"
    SiteSetting.backup_location = BackupLocationSiteSetting::S3

    prepare_fake_s3
    stub_download_object_filehelper
  end

  describe "#ban_user_from_external_uploads!" do
    after { Discourse.redis.flushdb }

    it "bans the user from external uploads using a redis key" do
      ExternalUploadManager.ban_user_from_external_uploads!(user: user)
      expect(ExternalUploadManager.user_banned?(user)).to eq(true)
    end
  end

  describe "#can_promote?" do
    it "returns false if the external stub status is not created" do
      external_upload_stub.update!(status: ExternalUploadStub.statuses[:uploaded])
      expect(subject.can_promote?).to eq(false)
    end
  end

  describe "#transform!" do
    context "when stubbed upload is < DOWNLOAD_LIMIT (small enough to download + generate sha)" do
      let!(:external_upload_stub) do
        Fabricate(:image_external_upload_stub, created_by: user, filesize: object_size)
      end
      let(:object_size) { 1.megabyte }
      let(:object_file) { logo_file }

      context "when the download of the s3 file fails" do
        before { FileHelper.stubs(:download).returns(nil) }

        it "raises an error" do
          expect { subject.transform! }.to raise_error(ExternalUploadManager::DownloadFailedError)
        end
      end

      context "when the upload is not in the created status" do
        before { external_upload_stub.update!(status: ExternalUploadStub.statuses[:uploaded]) }

        it "raises an error" do
          expect { subject.transform! }.to raise_error(ExternalUploadManager::CannotPromoteError)
        end
      end

      context "when the upload does not get changed in UploadCreator (resized etc.)" do
        it "copies the stubbed upload on S3 to its new destination and deletes it" do
          upload = subject.transform!

          bucket = @fake_s3.bucket(SiteSetting.s3_upload_bucket)
          expect(@fake_s3.operation_called?(:copy_object)).to eq(true)
          expect(bucket.find_object(Discourse.store.get_path_for_upload(upload))).to be_present
          expect(bucket.find_object(external_upload_stub.key)).to be_nil
        end

        it "errors if the image upload is too big" do
          SiteSetting.max_image_size_kb = 1
          upload = subject.transform!
          expect(upload.errors.full_messages).to include(
            "Filesize " +
              I18n.t(
                "upload.images.too_large_humanized",
                max_size:
                  ActiveSupport::NumberHelper.number_to_human_size(
                    SiteSetting.max_image_size_kb.kilobytes,
                  ),
              ),
          )
        end

        it "errors if the extension is not supported" do
          SiteSetting.authorized_extensions = ""
          upload = subject.transform!
          expect(upload.errors.full_messages).to include(
            "Original filename " + I18n.t("upload.unauthorized", authorized_extensions: ""),
          )
        end
      end

      context "when the upload does get changed by the UploadCreator" do
        let(:object_file) { file_from_fixtures("should_be_jpeg.heic", "images") }
        let(:object_size) { 1.megabyte }
        let(:external_upload_stub) do
          Fabricate(
            :image_external_upload_stub,
            original_filename: "should_be_jpeg.heic",
            filesize: object_size,
          )
        end

        it "creates a new upload in s3 (not copy) and deletes the original stubbed upload" do
          upload = subject.transform!

          bucket = @fake_s3.bucket(SiteSetting.s3_upload_bucket)
          expect(@fake_s3.operation_called?(:copy_object)).to eq(false)
          expect(bucket.find_object(Discourse.store.get_path_for_upload(upload))).to be_present
          expect(bucket.find_object(external_upload_stub.key)).to be_nil
        end
      end

      context "when the sha has been set on the s3 object metadata by the clientside JS" do
        let(:external_upload_stub_metadata) { { "sha1-checksum" => client_sha1 } }

        context "when the downloaded file sha1 does not match the client sha1" do
          let(:client_sha1) { "blahblah" }

          it "raises an error, deletes the stub" do
            expect { subject.transform! }.to raise_error(
              ExternalUploadManager::ChecksumMismatchError,
            )
            expect(ExternalUploadStub.exists?(id: external_upload_stub.id)).to eq(false)

            bucket = @fake_s3.bucket(SiteSetting.s3_upload_bucket)
            expect(bucket.find_object(external_upload_stub.key)).to be_nil
          end

          it "does not delete the stub if enable_upload_debug_mode" do
            SiteSetting.enable_upload_debug_mode = true
            expect { subject.transform! }.to raise_error(
              ExternalUploadManager::ChecksumMismatchError,
            )
            external_stub = ExternalUploadStub.find(external_upload_stub.id)
            expect(external_stub.status).to eq(ExternalUploadStub.statuses[:failed])

            bucket = @fake_s3.bucket(SiteSetting.s3_upload_bucket)
            expect(bucket.find_object(external_upload_stub.key)).to be_present
          end
        end
      end

      context "when the downloaded file size does not match the expected file size for the upload stub" do
        before { external_upload_stub.update!(filesize: 10) }

        after { Discourse.redis.flushdb }

        it "raises an error, deletes the file immediately, and prevents the user from uploading external files for a few minutes" do
          expect { subject.transform! }.to raise_error(ExternalUploadManager::SizeMismatchError)
          expect(ExternalUploadStub.exists?(id: external_upload_stub.id)).to eq(false)
          expect(
            Discourse.redis.get(
              "#{ExternalUploadManager::BAN_USER_REDIS_PREFIX}#{external_upload_stub.created_by_id}",
            ),
          ).to eq("1")

          bucket = @fake_s3.bucket(SiteSetting.s3_upload_bucket)
          expect(bucket.find_object(external_upload_stub.key)).to be_nil
        end

        it "does not delete the stub if enable_upload_debug_mode" do
          SiteSetting.enable_upload_debug_mode = true
          expect { subject.transform! }.to raise_error(ExternalUploadManager::SizeMismatchError)
          external_stub = ExternalUploadStub.find(external_upload_stub.id)
          expect(external_stub.status).to eq(ExternalUploadStub.statuses[:failed])

          bucket = @fake_s3.bucket(SiteSetting.s3_upload_bucket)
          expect(bucket.find_object(external_upload_stub.key)).to be_present
        end
      end
    end

    context "when stubbed upload is > DOWNLOAD_LIMIT (too big to download, generate a fake sha)" do
      let(:object_size) { 200.megabytes }
      let(:object_file) { pdf_file }
      let!(:external_upload_stub) do
        Fabricate(:attachment_external_upload_stub, created_by: user, filesize: object_size)
      end

      before do
        UploadCreator
          .any_instance
          .stubs(:generate_fake_sha1_hash)
          .returns("testbc60eb18e8f974cbfae8bb0f069c3a311024")
      end

      it "does not try and download the file" do
        FileHelper.expects(:download).never
        subject.transform!
      end

      it "generates a fake sha for the upload record" do
        upload = subject.transform!
        expect(upload.sha1).not_to eq(sha1)
        expect(upload.original_sha1).to eq(nil)
        expect(upload.filesize).to eq(object_size)
      end

      it "marks the stub as uploaded" do
        subject.transform!
        expect(external_upload_stub.reload.status).to eq(ExternalUploadStub.statuses[:uploaded])
      end

      it "copies the stubbed upload on S3 to its new destination and deletes it" do
        upload = subject.transform!

        bucket = @fake_s3.bucket(SiteSetting.s3_upload_bucket)
        expect(bucket.find_object(Discourse.store.get_path_for_upload(upload))).to be_present
        expect(bucket.find_object(external_upload_stub.key)).to be_nil
      end
    end

    context "when the upload type is backup" do
      let(:object_size) { 200.megabytes }
      let(:object_file) { file_from_fixtures("backup_since_v1.6.tar.gz", "backups") }
      let!(:external_upload_stub) do
        Fabricate(
          :attachment_external_upload_stub,
          created_by: user,
          filesize: object_size,
          upload_type: "backup",
          original_filename: "backup_since_v1.6.tar.gz",
          folder_prefix: RailsMultisite::ConnectionManagement.current_db,
        )
      end
      let(:s3_bucket_name) { SiteSetting.s3_backup_bucket }

      it "does not try and download the file" do
        FileHelper.expects(:download).never
        subject.transform!
      end

      it "raises an error when backups are disabled" do
        SiteSetting.enable_backups = false
        expect { subject.transform! }.to raise_error(Discourse::InvalidAccess)
      end

      it "raises an error when backups are local, not s3" do
        SiteSetting.backup_location = BackupLocationSiteSetting::LOCAL
        expect { subject.transform! }.to raise_error(Discourse::InvalidAccess)
      end

      it "does not create an upload record" do
        expect { subject.transform! }.not_to change { Upload.count }
      end

      it "copies the stubbed upload on S3 to its new destination and deletes it" do
        bucket = @fake_s3.bucket(SiteSetting.s3_backup_bucket)
        expect(bucket.find_object(external_upload_stub.key)).to be_present

        subject.transform!

        expect(
          bucket.find_object(
            "#{RailsMultisite::ConnectionManagement.current_db}/backup_since_v1.6.tar.gz",
          ),
        ).to be_present
        expect(bucket.find_object(external_upload_stub.key)).to be_nil
      end
    end
  end

  def stub_download_object_filehelper
    signed_url = Discourse.store.signed_url_for_path(external_upload_stub.key)
    uri = URI.parse(signed_url)
    signed_url = uri.to_s.gsub(uri.query, "")
    stub_request(:get, signed_url).with(query: hash_including({})).to_return(
      status: 200,
      body: object_file.read,
    )
  end

  def prepare_fake_s3
    @fake_s3 = FakeS3.create

    @fake_s3.bucket(s3_bucket_name).put_object(
      key: external_upload_stub.key,
      size: object_size,
      last_modified: Time.zone.now,
      metadata: external_upload_stub_metadata,
    )
  end
end
