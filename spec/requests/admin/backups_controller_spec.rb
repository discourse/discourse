require 'rails_helper'

RSpec.describe Admin::BackupsController do
  let(:admin) { Fabricate(:admin) }
  let(:backup_filename) { "2014-02-10-065935.tar.gz" }
  let(:backup_filename2) { "2014-02-11-065935.tar.gz" }

  it "is a subclass of AdminController" do
    expect(Admin::BackupsController < Admin::AdminController).to eq(true)
  end

  before do
    sign_in(admin)
  end

  after do
    $redis.flushall
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

        preloaded = controller.instance_variable_get("@preloaded").map do |key, value|
          [key, JSON.parse(value)]
        end.to_h

        expect(preloaded["backups"].size).to eq(Backup.all.size)
        expect(preloaded["operations_status"].symbolize_keys).to eq(BackupRestore.operations_status)
        expect(preloaded["logs"].size).to eq(BackupRestore.logs.size)
      end
    end

    context "json format" do
      it "returns a list of all the backups" do
        begin
          paths = []
          [backup_filename, backup_filename2].each do |name|
            path = File.join(Backup.base_directory, name)
            paths << path
            File.open(path, "w") { |f| f.write("hello") }
            Backup.create_from_filename(name)
          end

          get "/admin/backups.json"

          expect(response.status).to eq(200)

          json = JSON.parse(response.body).map { |backup| backup["filename"] }
          expect(json).to include(backup_filename)
          expect(json).to include(backup_filename2)
        ensure
          paths.each { |path| File.delete(path) }
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
        path = File.join(Backup.base_directory, backup_filename)
        File.open(path, "w") { |f| f.write("hello") }

        Backup.create_from_filename(backup_filename)

        expect do
          get "/admin/backups/#{backup_filename}.json", params: { token: token }
        end.to change { UserHistory.where(action: UserHistory.actions[:backup_download]).count }.by(1)

        expect(response.headers['Content-Length']).to eq("5")
        expect(response.headers['Content-Disposition']).to match(/attachment; filename/)
      ensure
        File.delete(path)
        EmailBackupToken.del(admin.id)
      end
    end

    it "returns 422 when token is bad" do
      begin
        path = File.join(Backup.base_directory, backup_filename)
        File.open(path, "w") { |f| f.write("hello") }

        Backup.create_from_filename(backup_filename)

        get "/admin/backups/#{backup_filename}.json", params: { token: "bad_value" }

        expect(response.status).to eq(422)
        expect(response.headers['Content-Disposition']).not_to match(/attachment; filename/)
      ensure
        File.delete(path)
      end
    end

    it "returns 404 when the backup does not exist" do
      token = EmailBackupToken.set(admin.id)
      get "/admin/backups/#{backup_filename}.json", params: { token: token }

      EmailBackupToken.del(admin.id)
      expect(response.status).to eq(404)
    end
  end

  describe '#destroy' do
    let(:b) { Backup.new(backup_filename) }

    it "removes the backup if found" do
      begin
        path = File.join(Backup.base_directory, backup_filename)
        File.open(path, "w") { |f| f.write("hello") }

        Backup.create_from_filename(backup_filename)

        expect do
          delete "/admin/backups/#{backup_filename}.json"
        end.to change { UserHistory.where(action: UserHistory.actions[:backup_destroy]).count }.by(1)

        expect(response.status).to eq(200)
        expect(File.exists?(path)).to eq(false)
      ensure
        File.delete(path) if File.exists?(path)
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

      preloaded = controller.instance_variable_get("@preloaded").map do |key, value|
        [key, JSON.parse(value)]
      end.to_h

      expect(preloaded["operations_status"].symbolize_keys).to eq(BackupRestore.operations_status)
      expect(preloaded["logs"].size).to eq(BackupRestore.logs.size)
    end
  end

  describe '#restore' do
    it "starts a restore" do
      expect(SiteSetting.disable_emails).to eq("no")
      BackupRestore.expects(:restore!).with(admin.id, filename: backup_filename, publish_to_message_bus: true, client_id: "foo")

      post "/admin/backups/#{backup_filename}/restore.json", params: { client_id: "foo" }

      expect(SiteSetting.disable_emails).to eq("yes")
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
            resumableFilename: invalid_filename, resumableTotalSize: 1
          }

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

          post "/admin/backups/upload.json", params: {
            resumableFilename: filename,
            resumableTotalSize: 1,
            resumableIdentifier: 'test',
            resumableChunkNumber: '1',
            resumableChunkSize: '1',
            resumableCurrentChunkSize: '1',
            file: fixture_file_upload(Tempfile.new)
          }

          expect(response.status).to eq(200)
          expect(response.body).to eq("")
        ensure
          begin
            File.delete(
              File.join(Backup.base_directory, 'tmp', 'test', "#{filename}.part1")
            )
          rescue Errno::ENOENT
          end
        end
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
    let(:backup_filename) { "test.tar.gz" }
    let(:backup) { Backup.new(backup_filename) }

    it "enqueues email job" do
      Backup.expects(:[]).with(backup_filename).returns(backup)

      Jobs.expects(:enqueue).with(:download_backup_email,
        user_id: admin.id,
        backup_file_path: 'http://www.example.com/admin/backups/test.tar.gz'
      )

      put "/admin/backups/#{backup_filename}.json"

      expect(response.status).to eq(200)
    end

    it "returns 404 when the backup does not exist" do
      put "/admin/backups/#{backup_filename}.json"

      expect(response).to be_not_found
    end
  end
end
