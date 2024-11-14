# frozen_string_literal: true

RSpec.describe Admin::BackupsController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)

  let(:backup_filename) { "2014-02-10-065935.tar.gz" }
  let(:backup_filename2) { "2014-02-11-065935.tar.gz" }

  def create_backup_files(*filenames)
    @paths =
      filenames.map do |filename|
        path = backup_path(filename)
        File.open(path, "w") { |f| f.write("test backup") }
        path
      end
  end

  def backup_path(filename)
    File.join(BackupRestore::LocalBackupStore.base_directory, filename)
  end

  def map_preloaded
    controller
      .instance_variable_get("@preloaded")
      .map { |key, value| [key, JSON.parse(value)] }
      .to_h
  end

  before { SiteSetting.backup_location = BackupLocationSiteSetting::LOCAL }

  after do
    Discourse.redis.flushdb

    @paths&.each { |path| File.delete(path) if File.exist?(path) }
    @paths = nil
  end

  describe "#index" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "raises an error when backups are disabled" do
        SiteSetting.enable_backups = false
        get "/admin/backups.json"
        expect(response.status).to eq(403)
      end

      context "with html format" do
        it "preloads important data" do
          get "/admin/backups.html"
          expect(response.status).to eq(200)

          preloaded = map_preloaded
          expect(preloaded["operations_status"].symbolize_keys).to eq(
            BackupRestore.operations_status,
          )
          expect(preloaded["logs"].size).to eq(BackupRestore.logs.size)
        end
      end

      context "with json format" do
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

    shared_examples "backups inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/backups.html"

        expect(response.status).to eq(404)

        get "/admin/backups.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "backups inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "backups inaccessible"
    end
  end

  describe "#status" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "returns the current backups status" do
        get "/admin/backups/status.json"
        expect(response.body).to eq(BackupRestore.operations_status.to_json)
        expect(response.status).to eq(200)
      end
    end

    shared_examples "status inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/backups/status.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "status inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "status inaccessible"
    end
  end

  describe "#create" do
    context "when logged in as an admin" do
      before do
        sign_in(admin)
        BackupRestore.stubs(:backup!)
      end

      it "starts a backup" do
        BackupRestore.expects(:backup!).with(
          admin.id,
          { publish_to_message_bus: true, with_uploads: false, client_id: "foo" },
        )

        post "/admin/backups.json", params: { with_uploads: false, client_id: "foo" }

        expect(response.status).to eq(200)
      end

      context "with rate limiting enabled" do
        before { RateLimiter.enable }

        after { RateLimiter.disable }

        it "is rate limited" do
          post "/admin/backups.json", params: { with_uploads: false, client_id: "foo" }
          post "/admin/backups.json", params: { with_uploads: false, client_id: "foo" }

          expect(response).to have_http_status :too_many_requests
        end
      end
    end

    shared_examples "backups creation not allowed" do
      it "prevents backups creation with a 404 response" do
        post "/admin/backups.json", params: { with_uploads: false, client_id: "foo" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "backups creation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "backups creation not allowed"
    end
  end

  describe "#show" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "uses send_file to transmit the backup" do
        begin
          token = EmailBackupToken.set(admin.id)
          create_backup_files(backup_filename)

          expect do
            get "/admin/backups/#{backup_filename}.json", params: { token: token }
          end.to change {
            UserHistory.where(action: UserHistory.actions[:backup_download]).count
          }.by(1)

          expect(response.headers["Content-Length"]).to eq("11")
          expect(response.headers["Content-Disposition"]).to match(/attachment; filename/)
        end
      end

      it "returns 422 when token is bad" do
        begin
          get "/admin/backups/#{backup_filename}.json", params: { token: "bad_value" }

          expect(response.status).to eq(422)
          expect(response.headers["Content-Disposition"]).not_to match(/attachment; filename/)
          expect(response.body).to include(I18n.t("download_backup_mailer.no_token"))
        end
      end

      it "returns 404 when the backup does not exist" do
        token = EmailBackupToken.set(admin.id)
        get "/admin/backups/#{backup_filename}.json", params: { token: token }

        expect(response.status).to eq(404)
      end
    end

    shared_examples "backup inaccessible" do
      it "denies access with a 404 response" do
        begin
          token = EmailBackupToken.set(admin.id)
          create_backup_files(backup_filename)

          expect do
            get "/admin/backups/#{backup_filename}.json", params: { token: token }
          end.not_to change {
            UserHistory.where(action: UserHistory.actions[:backup_download]).count
          }

          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
          expect(response.headers["Content-Disposition"]).not_to match(/attachment; filename/)
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "backup inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "backup inaccessible"
    end
  end

  describe "#destroy" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "removes the backup if found" do
        begin
          path = backup_path(backup_filename)
          create_backup_files(backup_filename)
          expect(File.exist?(path)).to eq(true)

          expect do delete "/admin/backups/#{backup_filename}.json" end.to change {
            UserHistory.where(action: UserHistory.actions[:backup_destroy]).count
          }.by(1)

          expect(response.status).to eq(200)
          expect(File.exist?(path)).to eq(false)
        end
      end

      it "doesn't remove the backup if not found" do
        delete "/admin/backups/#{backup_filename}.json"
        expect(response.status).to eq(404)
      end
    end

    shared_examples "backup deletion not allowed" do
      it "prevents deletion with a 404 response" do
        begin
          path = backup_path(backup_filename)
          create_backup_files(backup_filename)
          expect(File.exist?(path)).to eq(true)

          expect do delete "/admin/backups/#{backup_filename}.json" end.not_to change {
            UserHistory.where(action: UserHistory.actions[:backup_destroy]).count
          }

          expect(response.status).to eq(404)
          expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
          expect(File.exist?(path)).to eq(true)
        end
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "backup deletion not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "backup deletion not allowed"
    end
  end

  describe "#logs" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "preloads important data" do
        get "/admin/backups/logs.html"
        expect(response.status).to eq(200)

        preloaded = map_preloaded

        expect(preloaded["operations_status"].symbolize_keys).to eq(BackupRestore.operations_status)
        expect(preloaded["logs"].size).to eq(BackupRestore.logs.size)
      end
    end

    shared_examples "backup logs inaccessible" do
      it "denies access with a 404 response" do
        get "/admin/backups/logs.html"

        expect(response.status).to eq(404)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "backup logs inaccessible"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "backup logs inaccessible"
    end
  end

  describe "#restore" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "starts a restore" do
        BackupRestore.expects(:restore!).with(
          admin.id,
          { filename: backup_filename, publish_to_message_bus: true, client_id: "foo" },
        )

        post "/admin/backups/#{backup_filename}/restore.json", params: { client_id: "foo" }

        expect(response.status).to eq(200)
      end
    end

    shared_examples "backup restoration not allowed" do
      it "prevents restoration with a 404 response" do
        post "/admin/backups/#{backup_filename}/restore.json", params: { client_id: "foo" }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "backup restoration not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "backup restoration not allowed"
    end
  end

  describe "#readonly" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "enables readonly mode" do
        expect(Discourse.readonly_mode?).to eq(false)

        expect { put "/admin/backups/readonly.json", params: { enable: true } }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_readonly_mode],
            new_value: "t",
          ).count
        }.by(1)

        expect(Discourse.readonly_mode?).to eq(true)
        expect(response.status).to eq(200)
      end

      it "disables readonly mode" do
        Discourse.enable_readonly_mode(Discourse::USER_READONLY_MODE_KEY)
        expect(Discourse.readonly_mode?).to eq(true)

        expect { put "/admin/backups/readonly.json", params: { enable: false } }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_readonly_mode],
            new_value: "f",
          ).count
        }.by(1)

        expect(response.status).to eq(200)
        expect(Discourse.readonly_mode?).to eq(false)
      end
    end

    shared_examples "enabling readonly mode not allowed" do
      it "prevents enabling readonly mode with a 404 response" do
        expect(Discourse.readonly_mode?).to eq(false)

        expect do put "/admin/backups/readonly.json", params: { enable: true } end.not_to change {
          UserHistory.where(
            action: UserHistory.actions[:change_readonly_mode],
            new_value: "t",
          ).count
        }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
        expect(Discourse.readonly_mode?).to eq(false)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "enabling readonly mode not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "enabling readonly mode not allowed"
    end
  end

  describe "#upload_backup_chunk" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      describe "when filename contains invalid characters" do
        it "should raise an error" do
          ["灰色.tar.gz", '; echo \'haha\'.tar.gz'].each do |invalid_filename|
            described_class.any_instance.expects(:has_enough_space_on_disk?).returns(true)

            post "/admin/backups/upload",
                 params: {
                   resumableFilename: invalid_filename,
                   resumableTotalSize: 1,
                   resumableIdentifier: "test",
                 }

            expect(response.status).to eq(415)
            expect(response.body).to eq(I18n.t("backup.invalid_filename"))
          end
        end
      end

      describe "when resumableIdentifier is invalid" do
        it "should raise an error" do
          filename = "test_site-0123456789.tar.gz"
          @paths = [backup_path(File.join("tmp", "test", "#{filename}.part1"))]

          post "/admin/backups/upload.json",
               params: {
                 resumableFilename: filename,
                 resumableTotalSize: 1,
                 resumableIdentifier: "../test",
                 resumableChunkNumber: "1",
                 resumableChunkSize: "1",
                 resumableCurrentChunkSize: "1",
                 file: fixture_file_upload(Tempfile.new),
               }

          expect(response.status).to eq(400)
        end
      end

      describe "when filename is valid" do
        it "should upload the file successfully" do
          freeze_time
          described_class.any_instance.expects(:has_enough_space_on_disk?).returns(true)

          filename = "test_Site-0123456789.tar.gz"

          post "/admin/backups/upload.json",
               params: {
                 resumableFilename: filename,
                 resumableTotalSize: 1,
                 resumableIdentifier: "test",
                 resumableChunkNumber: "1",
                 resumableChunkSize: "1",
                 resumableCurrentChunkSize: "1",
                 file: fixture_file_upload(Tempfile.new),
               }
          expect_job_enqueued(
            job: :backup_chunks_merger,
            args: {
              filename: filename,
              identifier: "test",
              chunks: 1,
            },
            at: 5.seconds.from_now,
          )

          expect(response.status).to eq(200)
          expect(response.body).to eq("")
        end
      end

      describe "completing an upload by enqueuing backup_chunks_merger" do
        let(:filename) { "test_Site-0123456789.tar.gz" }

        it "works with a single chunk" do
          freeze_time
          described_class.any_instance.expects(:has_enough_space_on_disk?).returns(true)

          # 2MB file, 2MB chunks = 1x 2MB chunk
          post "/admin/backups/upload.json",
               params: {
                 resumableFilename: filename,
                 resumableTotalSize: "2097152",
                 resumableIdentifier: "test",
                 resumableChunkNumber: "1",
                 resumableChunkSize: "2097152",
                 resumableCurrentChunkSize: "2097152",
                 file: fixture_file_upload(Tempfile.new),
               }
          expect_job_enqueued(
            job: :backup_chunks_merger,
            args: {
              filename: filename,
              identifier: "test",
              chunks: 1,
            },
            at: 5.seconds.from_now,
          )
        end

        it "works with multiple chunks when the final chunk is chunk_size + remainder" do
          freeze_time
          described_class.any_instance.expects(:has_enough_space_on_disk?).twice.returns(true)

          # 5MB file, 2MB chunks = 1x 2MB chunk + 1x 3MB chunk with resumable.js
          post "/admin/backups/upload.json",
               params: {
                 resumableFilename: filename,
                 resumableTotalSize: "5242880",
                 resumableIdentifier: "test",
                 resumableChunkNumber: "1",
                 resumableChunkSize: "2097152",
                 resumableCurrentChunkSize: "2097152",
                 file: fixture_file_upload(Tempfile.new),
               }
          post "/admin/backups/upload.json",
               params: {
                 resumableFilename: filename,
                 resumableTotalSize: "5242880",
                 resumableIdentifier: "test",
                 resumableChunkNumber: "2",
                 resumableChunkSize: "2097152",
                 resumableCurrentChunkSize: "3145728",
                 file: fixture_file_upload(Tempfile.new),
               }
          expect_job_enqueued(
            job: :backup_chunks_merger,
            args: {
              filename: filename,
              identifier: "test",
              chunks: 2,
            },
            at: 5.seconds.from_now,
          )
        end

        it "works with multiple chunks when the final chunk is just the remainder" do
          freeze_time
          described_class.any_instance.expects(:has_enough_space_on_disk?).times(3).returns(true)

          # 5MB file, 2MB chunks = 2x 2MB chunk + 1x 1MB chunk with uppy.js
          post "/admin/backups/upload.json",
               params: {
                 resumableFilename: filename,
                 resumableTotalSize: "5242880",
                 resumableIdentifier: "test",
                 resumableChunkNumber: "1",
                 resumableChunkSize: "2097152",
                 resumableCurrentChunkSize: "2097152",
                 file: fixture_file_upload(Tempfile.new),
               }
          post "/admin/backups/upload.json",
               params: {
                 resumableFilename: filename,
                 resumableTotalSize: "5242880",
                 resumableIdentifier: "test",
                 resumableChunkNumber: "2",
                 resumableChunkSize: "2097152",
                 resumableCurrentChunkSize: "2097152",
                 file: fixture_file_upload(Tempfile.new),
               }
          post "/admin/backups/upload.json",
               params: {
                 resumableFilename: filename,
                 resumableTotalSize: "5242880",
                 resumableIdentifier: "test",
                 resumableChunkNumber: "3",
                 resumableChunkSize: "2097152",
                 resumableCurrentChunkSize: "1048576",
                 file: fixture_file_upload(Tempfile.new),
               }
          expect_job_enqueued(
            job: :backup_chunks_merger,
            args: {
              filename: filename,
              identifier: "test",
              chunks: 3,
            },
            at: 5.seconds.from_now,
          )
        end
      end
    end

    shared_examples "uploading backup chunk not allowed" do
      it "prevents uploading of backup chunk with a 404 response" do
        freeze_time
        filename = "test_Site-0123456789.tar.gz"

        post "/admin/backups/upload.json",
             params: {
               resumableFilename: filename,
               resumableTotalSize: 1,
               resumableIdentifier: "test",
               resumableChunkNumber: "1",
               resumableChunkSize: "1",
               resumableCurrentChunkSize: "1",
               file: fixture_file_upload(Tempfile.new),
             }

        expect_not_enqueued_with(
          job: :backup_chunks_merger,
          args: {
            filename: filename,
            identifier: "test",
            chunks: 1,
          },
          at: 5.seconds.from_now,
        )

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "uploading backup chunk not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "uploading backup chunk not allowed"
    end
  end

  describe "#check_backup_chunk" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      describe "when resumableIdentifier is invalid" do
        it "should raise an error" do
          get "/admin/backups/upload",
              params: {
                resumableidentifier: "../some_file",
                resumablefilename: "test_site-0123456789.tar.gz",
                resumablechunknumber: "1",
                resumablecurrentchunksize: "1",
              }

          expect(response.status).to eq(400)
        end
      end
    end

    shared_examples "checking backup chunk not allowed" do
      it "denies access with a 404 response" do
        get "/admin/backups/upload",
            params: {
              resumableidentifier: "../some_file",
              resumablefilename: "test_site-0123456789.tar.gz",
              resumablechunknumber: "1",
              resumablecurrentchunksize: "1",
            }

        expect(response.status).to eq(404)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "checking backup chunk not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "checking backup chunk not allowed"
    end
  end

  describe "#rollback" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should rollback the restore" do
        BackupRestore.expects(:rollback!)

        post "/admin/backups/rollback.json"

        expect(response.status).to eq(200)
      end

      it "should not allow rollback via a GET request" do
        get "/admin/backups/rollback.json"
        expect(response.status).to eq(404)
      end
    end

    shared_examples "backup rollback not allowed" do
      it "prevents rollbacks with a 404 response" do
        post "/admin/backups/rollback.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "backup rollback not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "backup rollback not allowed"
    end
  end

  describe "#cancel" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "should cancel an backup" do
        BackupRestore.expects(:cancel!)

        delete "/admin/backups/cancel.json"

        expect(response.status).to eq(200)
      end

      it "should not allow cancel via a GET request" do
        get "/admin/backups/cancel.json"
        expect(response.status).to eq(404)
      end
    end

    shared_examples "backup cancellation not allowed" do
      it "prevents cancellation with a 404 response" do
        delete "/admin/backups/cancel.json"

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "backup cancellation not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "backup cancellation not allowed"
    end
  end

  describe "#email" do
    context "when logged in as an admin" do
      before { sign_in(admin) }

      it "enqueues email job" do
        # might as well test this here if we really want www.example.com
        SiteSetting.force_hostname = "www.example.com"

        create_backup_files(backup_filename)

        expect { put "/admin/backups/#{backup_filename}.json" }.to change {
          Jobs::DownloadBackupEmail.jobs.size
        }.by(1)

        job_args = Jobs::DownloadBackupEmail.jobs.last["args"].first
        expect(job_args["user_id"]).to eq(admin.id)
        expect(job_args["backup_file_path"]).to eq(
          "http://www.example.com/admin/backups/#{backup_filename}",
        )

        expect(response.status).to eq(200)
      end

      it "returns 404 when the backup does not exist" do
        put "/admin/backups/#{backup_filename}.json"

        expect(response).to be_not_found
      end
    end

    shared_examples "backup emails not allowed" do
      it "prevents sending backup emails with a 404 response" do
        SiteSetting.force_hostname = "www.example.com"
        create_backup_files(backup_filename)

        expect do put "/admin/backups/#{backup_filename}.json" end.not_to change {
          Jobs::DownloadBackupEmail.jobs.size
        }

        expect(response.status).to eq(404)
        expect(response.parsed_body["errors"]).to include(I18n.t("not_found"))
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "backup emails not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "backup emails not allowed"
    end
  end

  describe "S3 multipart uploads" do
    let(:upload_type) { "backup" }
    let(:test_bucket_prefix) { "test_#{ENV["TEST_ENV_NUMBER"].presence || "0"}" }
    let(:backup_file_exists_response) { { status: 404 } }
    let(:mock_multipart_upload_id) do
      "ibZBv_75gd9r8lH_gqXatLdxMVpAlj6CFTR.OwyF3953YdwbcQnMA2BLGn8Lx12fQNICtMw5KyteFeHw.Sjng--"
    end

    before do
      setup_s3
      SiteSetting.enable_direct_s3_uploads = true
      SiteSetting.s3_backup_bucket = "s3-backup-bucket"
      SiteSetting.backup_location = BackupLocationSiteSetting::S3
      stub_request(
        :head,
        "https://s3-backup-bucket.s3.dualstack.us-west-1.amazonaws.com/",
      ).to_return(status: 200, body: "", headers: {})
      stub_request(
        :head,
        "https://s3-backup-bucket.s3.dualstack.us-west-1.amazonaws.com/default/test.tar.gz",
      ).to_return(backup_file_exists_response)
    end

    shared_examples "multipart uploads not allowed" do
      it "prevents multipart uploads with a 404 response" do
        post "/admin/backups/create-multipart.json",
             params: {
               file_name: "test.tar.gz",
               upload_type: upload_type,
               file_size: 4098,
             }
        expect(response.status).to eq(404)
      end
    end

    context "when logged in as a moderator" do
      before { sign_in(moderator) }

      include_examples "multipart uploads not allowed"
    end

    context "when logged in as a non-staff user" do
      before { sign_in(user) }

      include_examples "multipart uploads not allowed"
    end

    context "when the user is admin" do
      before { sign_in(admin) }

      def stub_create_multipart_backup_request
        BackupRestore::S3BackupStore
          .any_instance
          .stubs(:temporary_upload_path)
          .returns(
            "temp/default/#{test_bucket_prefix}/28fccf8259bbe75b873a2bd2564b778c/2u98j832nx93272x947823.gz",
          )
        create_multipart_result = <<~XML
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>\n
        <InitiateMultipartUploadResult>
           <Bucket>s3-backup-bucket</Bucket>
           <Key>temp/default/#{test_bucket_prefix}/28fccf8259bbe75b873a2bd2564b778c/2u98j832nx93272x947823.gz</Key>
           <UploadId>#{mock_multipart_upload_id}</UploadId>
        </InitiateMultipartUploadResult>
        XML
        stub_request(
          :post,
          "https://s3-backup-bucket.s3.dualstack.us-west-1.amazonaws.com/temp/default/#{test_bucket_prefix}/28fccf8259bbe75b873a2bd2564b778c/2u98j832nx93272x947823.gz?uploads",
        ).to_return(status: 200, body: create_multipart_result)
      end

      it "creates the multipart upload" do
        stub_create_multipart_backup_request
        post "/admin/backups/create-multipart.json",
             params: {
               file_name: "test.tar.gz",
               upload_type: upload_type,
               file_size: 4098,
             }
        expect(response.status).to eq(200)
        result = response.parsed_body

        external_upload_stub =
          ExternalUploadStub.where(
            unique_identifier: result["unique_identifier"],
            original_filename: "test.tar.gz",
            created_by: admin,
            upload_type: upload_type,
            key: result["key"],
            multipart: true,
          )
        expect(external_upload_stub.exists?).to eq(true)
      end

      context "when backup of same filename already exists" do
        let(:backup_file_exists_response) { { status: 200, body: "" } }

        it "throws an error" do
          post "/admin/backups/create-multipart.json",
               params: {
                 file_name: "test.tar.gz",
                 upload_type: upload_type,
                 file_size: 4098,
               }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(I18n.t("backup.file_exists"))
        end
      end

      context "when filename is invalid" do
        it "throws an error" do
          post "/admin/backups/create-multipart.json",
               params: {
                 file_name: "blah $$##.tar.gz",
                 upload_type: upload_type,
                 file_size: 4098,
               }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(I18n.t("backup.invalid_filename"))
        end
      end

      context "when extension is invalid" do
        it "throws an error" do
          post "/admin/backups/create-multipart.json",
               params: {
                 file_name: "test.png",
                 upload_type: upload_type,
                 file_size: 4098,
               }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("backup.backup_file_should_be_tar_gz"),
          )
        end
      end
    end
  end
end
