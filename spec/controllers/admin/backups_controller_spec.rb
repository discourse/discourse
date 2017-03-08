require "rails_helper"

describe Admin::BackupsController do

  it "is a subclass of AdminController" do
    expect(Admin::BackupsController < Admin::AdminController).to eq(true)
  end

  let(:backup_filename) { "2014-02-10-065935.tar.gz" }

  context "while logged in as an admin" do

    before { @admin = log_in(:admin) }

    describe ".index" do

      context "html format" do

        it "preloads important data" do
          Backup.expects(:all).returns([])
          subject.expects(:store_preloaded).with("backups", "[]")

          BackupRestore.expects(:operations_status).returns({})
          subject.expects(:store_preloaded).with("operations_status", "{}")

          BackupRestore.expects(:logs).returns([])
          subject.expects(:store_preloaded).with("logs", "[]")

          xhr :get, :index, format: :html

          expect(response).to be_success
        end

      end

      context "json format" do

        it "returns a list of all the backups" do
          Backup.expects(:all).returns([Backup.new("backup1"), Backup.new("backup2")])

          xhr :get, :index, format: :json

          expect(response).to be_success

          json = JSON.parse(response.body)
          expect(json[0]["filename"]).to eq("backup1")
          expect(json[1]["filename"]).to eq("backup2")
        end

      end

    end

    describe ".status" do

      it "returns the current backups status" do
        BackupRestore.expects(:operations_status)

        xhr :get, :status

        expect(response).to be_success
      end

    end

    describe ".create" do

      it "starts a backup" do
        BackupRestore.expects(:backup!).with(@admin.id, publish_to_message_bus: true, with_uploads: false, client_id: "foo")

        xhr :post, :create, with_uploads: false, client_id: "foo"

        expect(response).to be_success
      end

    end

    describe ".cancel" do

      it "cancels an export" do
        BackupRestore.expects(:cancel!)

        xhr :delete, :cancel

        expect(response).to be_success
      end

    end

    describe ".show" do

      it "uses send_file to transmit the backup" do
        begin
          token = EmailBackupToken.set(@admin.id)
          path = File.join(Backup.base_directory, backup_filename)
          File.open(path, "w") { |f| f.write("hello") }

          Backup.create_from_filename(backup_filename)

          StaffActionLogger.any_instance.expects(:log_backup_download).once

          get :show, id: backup_filename, token: token


          expect(response.headers['Content-Length']).to eq("5")
          expect(response.headers['Content-Disposition']).to match(/attachment; filename/)
        ensure
          File.delete(path)
          EmailBackupToken.del(@admin.id)
        end
      end

      it "returns 422 when token is bad" do
        begin
          path = File.join(Backup.base_directory, backup_filename)
          File.open(path, "w") { |f| f.write("hello") }

          Backup.create_from_filename(backup_filename)

          get :show, id: backup_filename, token: "bad_value"

          expect(response.status).to eq(422)
        ensure
          File.delete(path)
        end
      end

      it "returns 404 when the backup does not exist" do
        token = EmailBackupToken.set(@admin.id)
        Backup.expects(:[]).returns(nil)

        get :show, id: backup_filename, token: token

        EmailBackupToken.del(@admin.id)

        expect(response).to be_not_found
      end

    end

    describe ".email" do

      let(:b) { Backup.new(backup_filename) }

      it "enqueues email job" do
        Backup.expects(:[]).with(backup_filename).returns(b)
        Jobs.expects(:enqueue).with(:download_backup_email, has_entries(to_address: @admin.email))

        xhr :put, :email, id: backup_filename

        expect(response).to be_success
      end

      it "returns 404 when the backup does not exist" do
        xhr :put, :email, id: backup_filename

        expect(response).to be_not_found
      end

    end

    describe ".destroy" do

      let(:b) { Backup.new(backup_filename) }

      it "removes the backup if found" do
        Backup.expects(:[]).with(backup_filename).returns(b)
        b.expects(:remove)

        StaffActionLogger.any_instance.expects(:log_backup_destroy).with(b).once

        xhr :delete, :destroy, id: backup_filename

        expect(response).to be_success
      end

      it "doesn't remove the backup if not found" do
        Backup.expects(:[]).with(backup_filename).returns(nil)
        b.expects(:remove).never
        xhr :delete, :destroy, id: backup_filename
        expect(response).not_to be_success
      end

    end

    describe ".logs" do

      it "preloads important data" do
        BackupRestore.expects(:operations_status).returns({})
        subject.expects(:store_preloaded).with("operations_status", "{}")

        BackupRestore.expects(:logs).returns([])
        subject.expects(:store_preloaded).with("logs", "[]")

        xhr :get, :logs, format: :html

        expect(response).to be_success
      end
    end

    describe ".restore" do

      it "starts a restore" do
        expect(SiteSetting.disable_emails).to eq(false)
        BackupRestore.expects(:restore!).with(@admin.id, filename: backup_filename, publish_to_message_bus: true, client_id: "foo")

        xhr :post, :restore, id: backup_filename, client_id: "foo"

        expect(SiteSetting.disable_emails).to eq(true)
        expect(response).to be_success
      end

    end

    describe ".rollback" do

      it "rolls back to previous working state" do
        BackupRestore.expects(:rollback!)

        xhr :get, :rollback

        expect(response).to be_success
      end

    end

    describe ".readonly" do

      it "enables readonly mode" do
        Discourse.expects(:enable_readonly_mode)

        expect { xhr :put, :readonly, enable: true }
          .to change { UserHistory.count }.by(1)

        expect(response).to be_success

        user_history = UserHistory.last

        expect(UserHistory.last.action).to eq(UserHistory.actions[:change_readonly_mode])
        expect(UserHistory.last.new_value).to eq('t')
      end

      it "disables readonly mode" do
        Discourse.expects(:disable_readonly_mode)

        expect { xhr :put, :readonly, enable: false }
          .to change { UserHistory.count }.by(1)

        expect(response).to be_success

        user_history = UserHistory.last

        expect(UserHistory.last.action).to eq(UserHistory.actions[:change_readonly_mode])
        expect(UserHistory.last.new_value).to eq('f')
      end

    end

    describe "#upload_backup_chunk" do
      describe "when filename contains invalid characters" do
        it "should raise an error" do
          ['灰色.tar.gz', '; echo \'haha\'.tar.gz'].each do |invalid_filename|
            described_class.any_instance.expects(:has_enough_space_on_disk?).returns(true)
            xhr :post, :upload_backup_chunk, resumableFilename: invalid_filename, resumableTotalSize: 1

            expect(response.status).to eq(415)
            expect(response.body).to eq(I18n.t('backup.invalid_filename'))
          end
        end
      end

      describe "when filename is valid" do
        it "should upload the file successfully" do
          begin
            described_class.any_instance.expects(:has_enough_space_on_disk?).returns(true)

            filename = 'test_Site-0123456789.tar.gz'

            xhr :post, :upload_backup_chunk,
              resumableFilename: filename,
              resumableTotalSize: 1,
              resumableIdentifier: 'test',
              resumableChunkNumber: '1',
              resumableChunkSize: '1',
              resumableCurrentChunkSize: '1',
              file: fixture_file_upload(Tempfile.new)

            expect(response.status).to eq(200)
            expect(response.body).to eq("")
          ensure
            File.delete(File.join(Backup.base_directory, filename))
          end
        end
      end
    end

  end

end
