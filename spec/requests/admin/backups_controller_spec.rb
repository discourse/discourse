# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Admin::BackupsController do
  fab!(:admin) { Fabricate(:admin) }
  let(:backup_filename) { "2014-02-10-065935.tar.gz" }
  let(:backup_filename2) { "2014-02-11-065935.tar.gz" }

  def create_backup_files(*filenames)
    @paths = filenames.map do |filename|
      path = backup_path(filename)
      File.open(path, "w") { |f| f.write("test backup") }
      path
    end
  end

  def backup_path(filename)
    File.join(BackupRestore::LocalBackupStore.base_directory, filename)
  end

  def map_preloaded
    controller.instance_variable_get("@preloaded").map do |key, value|
      [key, JSON.parse(value)]
    end.to_h
  end

  it "is a subclass of AdminController" do
    expect(Admin::BackupsController < Admin::AdminController).to eq(true)
  end

  before do
    sign_in(admin)
    SiteSetting.backup_location = BackupLocationSiteSetting::LOCAL
  end

  after do
    Discourse.redis.flushdb

    @paths&.each { |path| File.delete(path) if File.exist?(path) }
    @paths = nil
  end

  describe "#index" do
    it "raises an error when backups are disabled" do
      SiteSetting.enable_backups = false
      get "/admin/backups.json"
      expect(response.status).to eq(403)
    end

    context "html format" do
      it "preloads important data" do
        get "/admin/backups.html"
        expect(response.status).to eq(200)

        preloaded = map_preloaded
        expect(preloaded["operations_status"].symbolize_keys).to eq(BackupRestore.operations_status)
        expect(preloaded["logs"].size).to eq(BackupRestore.logs.size)
      end
    end

    context "json format" do
      it "returns a list of all the backups" do
        begin
          create_backup_files(backup_filename, backup_filename2)

          get "/admin/backups.json"
          expect(response.status).to eq(200)

          filenames = response.parsed_body.map { |backup| backup["filename"] }
          expect(filenames).to include(backup_filename)
          expect(filenames).to include(backup_filename2)
        end
      end
    end
  end

  describe '#status' do
    it "returns the current backups status" do
      get "/admin/backups/status.json"
      expect(response.body).to eq(BackupRestore.operations_status.to_json)
      expect(response.status).to eq(200)
    end
  end

  describe '#create' do
    it "starts a backup" do
      BackupRestore.expects(:backup!).with(admin.id, publish_to_message_bus: true, with_uploads: false, client_id: "foo")

      post "/admin/backups.json", params: {
        with_uploads: false, client_id: "foo"
      }

      expect(response.status).to eq(200)
    end
  end

  describe '#show' do
    it "uses send_file to transmit the backup" do
      begin
        token = EmailBackupToken.set(admin.id)
        create_backup_files(backup_filename)

        expect do
          get "/admin/backups/#{backup_filename}.json", params: { token: token }
        end.to change { UserHistory.where(action: UserHistory.actions[:backup_download]).count }.by(1)

        expect(response.headers['Content-Length']).to eq("11")
        expect(response.headers['Content-Disposition']).to match(/attachment; filename/)
      end
    end

    it "returns 422 when token is bad" do
      begin
        get "/admin/backups/#{backup_filename}.json", params: { token: "bad_value" }

        expect(response.status).to eq(422)
        expect(response.headers['Content-Disposition']).not_to match(/attachment; filename/)
        expect(response.body).to include(I18n.t("download_backup_mailer.no_token"))
      end
    end

    it "returns 404 when the backup does not exist" do
      token = EmailBackupToken.set(admin.id)
      get "/admin/backups/#{backup_filename}.json", params: { token: token }

      expect(response.status).to eq(404)
    end
  end

  describe '#destroy' do
    it "removes the backup if found" do
      begin
        path = backup_path(backup_filename)
        create_backup_files(backup_filename)
        expect(File.exist?(path)).to eq(true)

        expect do
          delete "/admin/backups/#{backup_filename}.json"
        end.to change { UserHistory.where(action: UserHistory.actions[:backup_destroy]).count }.by(1)

        expect(response.status).to eq(200)
        expect(File.exist?(path)).to eq(false)
      end
    end

    it "doesn't remove the backup if not found" do
      delete "/admin/backups/#{backup_filename}.json"
      expect(response.status).to eq(404)
    end
  end

  describe '#logs' do
    it "preloads important data" do
      get "/admin/backups/logs.html"
      expect(response.status).to eq(200)

      preloaded = map_preloaded

      expect(preloaded["operations_status"].symbolize_keys).to eq(BackupRestore.operations_status)
      expect(preloaded["logs"].size).to eq(BackupRestore.logs.size)
    end
  end

  describe '#restore' do
    it "starts a restore" do
      BackupRestore.expects(:restore!).with(admin.id, filename: backup_filename, publish_to_message_bus: true, client_id: "foo")

      post "/admin/backups/#{backup_filename}/restore.json", params: { client_id: "foo" }

      expect(response.status).to eq(200)
    end
  end

  describe '#readonly' do
    it "enables readonly mode" do
      expect(Discourse.readonly_mode?).to eq(false)

      expect { put "/admin/backups/readonly.json", params: { enable: true } }
        .to change { UserHistory.where(action: UserHistory.actions[:change_readonly_mode], new_value: "t").count }.by(1)

      expect(Discourse.readonly_mode?).to eq(true)
      expect(response.status).to eq(200)
    end

    it "disables readonly mode" do
      Discourse.enable_readonly_mode(Discourse::USER_READONLY_MODE_KEY)
      expect(Discourse.readonly_mode?).to eq(true)

      expect { put "/admin/backups/readonly.json", params: { enable: false } }
        .to change { UserHistory.where(action: UserHistory.actions[:change_readonly_mode], new_value: "f").count }.by(1)

      expect(response.status).to eq(200)
      expect(Discourse.readonly_mode?).to eq(false)
    end
  end

  describe "#upload_backup_chunk" do
    describe "when filename contains invalid characters" do
      it "should raise an error" do
        ['灰色.tar.gz', '; echo \'haha\'.tar.gz'].each do |invalid_filename|
          described_class.any_instance.expects(:has_enough_space_on_disk?).returns(true)

          post "/admin/backups/upload", params: {
            resumableFilename: invalid_filename,
            resumableTotalSize: 1,
            resumableIdentifier: 'test'
          }

          expect(response.status).to eq(415)
          expect(response.body).to eq(I18n.t('backup.invalid_filename'))
        end
      end
    end

    describe "when resumableIdentifier is invalid" do
      it "should raise an error" do
        filename = 'test_site-0123456789.tar.gz'
        @paths = [backup_path(File.join('tmp', 'test', "#{filename}.part1"))]

        post "/admin/backups/upload.json", params: {
          resumableFilename: filename,
          resumableTotalSize: 1,
          resumableIdentifier: '../test',
          resumableChunkNumber: '1',
          resumableChunkSize: '1',
          resumableCurrentChunkSize: '1',
          file: fixture_file_upload(Tempfile.new)
        }

        expect(response.status).to eq(400)
      end
    end

    describe "when filename is valid" do
      it "should upload the file successfully" do
        freeze_time
        described_class.any_instance.expects(:has_enough_space_on_disk?).returns(true)

        filename = 'test_Site-0123456789.tar.gz'

        post "/admin/backups/upload.json", params: {
          resumableFilename: filename,
          resumableTotalSize: 1,
          resumableIdentifier: 'test',
          resumableChunkNumber: '1',
          resumableChunkSize: '1',
          resumableCurrentChunkSize: '1',
          file: fixture_file_upload(Tempfile.new)
        }
        expect_job_enqueued(job: :backup_chunks_merger, args: {
          filename: filename, identifier: 'test', chunks: 1
        }, at: 5.seconds.from_now)

        expect(response.status).to eq(200)
        expect(response.body).to eq("")
      end
    end

    describe "completing an upload by enqueuing backup_chunks_merger" do
      let(:filename) { 'test_Site-0123456789.tar.gz' }

      it "works with a single chunk" do
        freeze_time
        described_class.any_instance.expects(:has_enough_space_on_disk?).returns(true)

        # 2MB file, 2MB chunks = 1x 2MB chunk
        post "/admin/backups/upload.json", params: {
          resumableFilename: filename,
          resumableTotalSize: '2097152',
          resumableIdentifier: 'test',
          resumableChunkNumber: '1',
          resumableChunkSize: '2097152',
          resumableCurrentChunkSize: '2097152',
          file: fixture_file_upload(Tempfile.new)
        }
        expect_job_enqueued(job: :backup_chunks_merger, args: {
          filename: filename, identifier: 'test', chunks: 1
        }, at: 5.seconds.from_now)
      end

      it "works with multiple chunks when the final chunk is chunk_size + remainder" do
        freeze_time
        described_class.any_instance.expects(:has_enough_space_on_disk?).twice.returns(true)

        # 5MB file, 2MB chunks = 1x 2MB chunk + 1x 3MB chunk with resumable.js
        post "/admin/backups/upload.json", params: {
          resumableFilename: filename,
          resumableTotalSize: '5242880',
          resumableIdentifier: 'test',
          resumableChunkNumber: '1',
          resumableChunkSize: '2097152',
          resumableCurrentChunkSize: '2097152',
          file: fixture_file_upload(Tempfile.new)
        }
        post "/admin/backups/upload.json", params: {
          resumableFilename: filename,
          resumableTotalSize: '5242880',
          resumableIdentifier: 'test',
          resumableChunkNumber: '2',
          resumableChunkSize: '2097152',
          resumableCurrentChunkSize: '3145728',
          file: fixture_file_upload(Tempfile.new)
        }
        expect_job_enqueued(job: :backup_chunks_merger, args: {
          filename: filename, identifier: 'test', chunks: 2
        }, at: 5.seconds.from_now)
      end

      it "works with multiple chunks when the final chunk is just the remaninder" do
        freeze_time
        described_class.any_instance.expects(:has_enough_space_on_disk?).times(3).returns(true)

        # 5MB file, 2MB chunks = 2x 2MB chunk + 1x 1MB chunk with uppy.js
        post "/admin/backups/upload.json", params: {
          resumableFilename: filename,
          resumableTotalSize: '5242880',
          resumableIdentifier: 'test',
          resumableChunkNumber: '1',
          resumableChunkSize: '2097152',
          resumableCurrentChunkSize: '2097152',
          file: fixture_file_upload(Tempfile.new)
        }
        post "/admin/backups/upload.json", params: {
          resumableFilename: filename,
          resumableTotalSize: '5242880',
          resumableIdentifier: 'test',
          resumableChunkNumber: '2',
          resumableChunkSize: '2097152',
          resumableCurrentChunkSize: '2097152',
          file: fixture_file_upload(Tempfile.new)
        }
        post "/admin/backups/upload.json", params: {
          resumableFilename: filename,
          resumableTotalSize: '5242880',
          resumableIdentifier: 'test',
          resumableChunkNumber: '3',
          resumableChunkSize: '2097152',
          resumableCurrentChunkSize: '1048576',
          file: fixture_file_upload(Tempfile.new)
        }
        expect_job_enqueued(job: :backup_chunks_merger, args: {
          filename: filename, identifier: 'test', chunks: 3
        }, at: 5.seconds.from_now)
      end
    end
  end

  describe "#check_backup_chunk" do
    describe "when resumableIdentifier is invalid" do
      it "should raise an error" do
        get "/admin/backups/upload", params: {
          resumableIdentifier: "../some_file",
          resumableFilename: "test_site-0123456789.tar.gz",
          resumableChunkNumber: '1',
          resumableCurrentChunkSize: '1'
        }

        expect(response.status).to eq(400)
      end
    end
  end

  describe '#rollback' do
    it 'should rollback the restore' do
      BackupRestore.expects(:rollback!)

      post "/admin/backups/rollback.json"

      expect(response.status).to eq(200)
    end

    it 'should not allow rollback via a GET request' do
      get "/admin/backups/rollback.json"
      expect(response.status).to eq(404)
    end
  end

  describe '#cancel' do
    it "should cancel an backup" do
      BackupRestore.expects(:cancel!)

      delete "/admin/backups/cancel.json"

      expect(response.status).to eq(200)
    end

    it 'should not allow cancel via a GET request' do
      get "/admin/backups/cancel.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#email" do
    it "enqueues email job" do

      # might as well test this here if we really want www.example.com
      SiteSetting.force_hostname = "www.example.com"

      create_backup_files(backup_filename)

      expect {
        put "/admin/backups/#{backup_filename}.json"
      }.to change { Jobs::DownloadBackupEmail.jobs.size }.by(1)

      job_args = Jobs::DownloadBackupEmail.jobs.last["args"].first
      expect(job_args["user_id"]).to eq(admin.id)
      expect(job_args["backup_file_path"]).to eq("http://www.example.com/admin/backups/#{backup_filename}")

      expect(response.status).to eq(200)
    end

    it "returns 404 when the backup does not exist" do
      put "/admin/backups/#{backup_filename}.json"

      expect(response).to be_not_found
    end
  end

  describe "S3 multipart uploads" do
    let(:upload_type) { "backup" }
    let(:test_bucket_prefix) { "test_#{ENV['TEST_ENV_NUMBER'].presence || '0'}" }
    let(:backup_file_exists_response) { { status: 404 } }
    let(:mock_multipart_upload_id) { "ibZBv_75gd9r8lH_gqXatLdxMVpAlj6CFTR.OwyF3953YdwbcQnMA2BLGn8Lx12fQNICtMw5KyteFeHw.Sjng--" }

    before do
      setup_s3
      SiteSetting.enable_direct_s3_uploads = true
      SiteSetting.s3_backup_bucket = "s3-backup-bucket"
      SiteSetting.backup_location = BackupLocationSiteSetting::S3
      stub_request(:head, "https://s3-backup-bucket.s3.us-west-1.amazonaws.com/").to_return(status: 200, body: "", headers: {})
      stub_request(:head, "https://s3-backup-bucket.s3.us-west-1.amazonaws.com/default/test.tar.gz").to_return(
        backup_file_exists_response
      )
    end

    context "when the user is not admin" do
      before do
        admin.update(admin: false)
      end

      it "errors with invalid access error" do
        post "/admin/backups/create-multipart.json", params: {
          file_name: "test.tar.gz",
          upload_type: upload_type,
          file_size: 4098
        }
        expect(response.status).to eq(404)
      end
    end

    context "when the user is admin" do
      def stub_create_multipart_backup_request
        BackupRestore::S3BackupStore.any_instance.stubs(:temporary_upload_path).returns(
          "temp/default/#{test_bucket_prefix}/28fccf8259bbe75b873a2bd2564b778c/2u98j832nx93272x947823.gz"
        )
        create_multipart_result = <<~BODY
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>\n
        <InitiateMultipartUploadResult>
           <Bucket>s3-backup-bucket</Bucket>
           <Key>temp/default/#{test_bucket_prefix}/28fccf8259bbe75b873a2bd2564b778c/2u98j832nx93272x947823.gz</Key>
           <UploadId>#{mock_multipart_upload_id}</UploadId>
        </InitiateMultipartUploadResult>
        BODY
        stub_request(:post, "https://s3-backup-bucket.s3.us-west-1.amazonaws.com/temp/default/#{test_bucket_prefix}/28fccf8259bbe75b873a2bd2564b778c/2u98j832nx93272x947823.gz?uploads").
          to_return(status: 200, body: create_multipart_result)
      end

      it "creates the multipart upload" do
        stub_create_multipart_backup_request
        post "/admin/backups/create-multipart.json", params: {
          file_name: "test.tar.gz",
          upload_type: upload_type,
          file_size: 4098
        }
        expect(response.status).to eq(200)
        result = response.parsed_body

        external_upload_stub = ExternalUploadStub.where(
          unique_identifier: result["unique_identifier"],
          original_filename: "test.tar.gz",
          created_by: admin,
          upload_type: upload_type,
          key: result["key"],
          multipart: true
        )
        expect(external_upload_stub.exists?).to eq(true)
      end

      context "when backup of same filename already exists" do
        let(:backup_file_exists_response) { { status: 200, body: "" } }

        it "throws an error" do
          post "/admin/backups/create-multipart.json", params: {
            file_name: "test.tar.gz",
            upload_type: upload_type,
            file_size: 4098
          }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("backup.file_exists")
          )
        end
      end

      context "when filename is invalid" do
        it "throws an error" do
          post "/admin/backups/create-multipart.json", params: {
            file_name: "blah $$##.tar.gz",
            upload_type: upload_type,
            file_size: 4098
          }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("backup.invalid_filename")
          )
        end
      end

      context "when extension is invalid" do
        it "throws an error" do
          post "/admin/backups/create-multipart.json", params: {
            file_name: "test.png",
            upload_type: upload_type,
            file_size: 4098
          }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("backup.backup_file_should_be_tar_gz")
          )
        end
      end
    end
  end
end
