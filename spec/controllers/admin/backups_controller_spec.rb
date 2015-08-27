require "spec_helper"

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
        FileUtils.mkdir_p Backup.base_directory
        File.open(Backup.base_directory << "/" << backup_filename, "w") do |f|
          f.write("hello")
        end

        Backup.create_from_filename(backup_filename)

        get :show, id: backup_filename

        expect(response.headers['Content-Length']).to eq(5)
        expect(response.headers['Content-Disposition']).to match(/attachment; filename/)
      end

      it "returns 404 when the backup does not exist" do
        Backup.expects(:[]).returns(nil)

        get :show, id: backup_filename

        expect(response).to be_not_found
      end

    end

    describe ".destroy" do

      let(:b) { Backup.new(backup_filename) }

      it "removes the backup if found" do
        Backup.expects(:[]).with(backup_filename).returns(b)
        b.expects(:remove)
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
        BackupRestore.expects(:restore!).with(@admin.id, filename: backup_filename, publish_to_message_bus: true, client_id: "foo")

        xhr :post, :restore, id: backup_filename, client_id: "foo"

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

        xhr :put, :readonly, enable: true

        expect(response).to be_success
      end

      it "disables readonly mode" do
        Discourse.expects(:disable_readonly_mode)

        xhr :put, :readonly, enable: false

        expect(response).to be_success
      end

    end

  end

end
