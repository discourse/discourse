require "spec_helper"

describe Admin::BackupsController do

  it "is a subclass of AdminController" do
    (Admin::BackupsController < Admin::AdminController).should be_true
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

          response.should be_success
        end

      end

      context "json format" do

        it "returns a list of all the backups" do
          Backup.expects(:all).returns([Backup.new("backup1"), Backup.new("backup2")])

          xhr :get, :index, format: :json

          response.should be_success

          json = JSON.parse(response.body)
          json[0]["filename"].should == "backup1"
          json[1]["filename"].should == "backup2"
        end

      end

    end

    describe ".status" do

      it "returns the current backups status" do
        BackupRestore.expects(:operations_status)

        xhr :get, :status

        response.should be_success
      end

    end

    describe ".create" do

      it "starts a backup" do
        BackupRestore.expects(:backup!).with(@admin.id, true)

        xhr :post, :create

        response.should be_success
      end

      # it "catches OperationRunningError exception" do
      #   BackupRestore.expects(:is_operation_running?).returns(true)

      #   xhr :post, :create

      #   response.should be_success

      #   json = JSON.parse(response.body)
      #   json["message"].should_not be_nil
      # end

    end

    describe ".cancel" do

      it "cancels an export" do
        BackupRestore.expects(:cancel!)

        xhr :delete, :cancel

        response.should be_success
      end

    end

    describe ".show" do

      it "uses send_file to transmit the backup" do
        controller.stubs(:render) # we need this since we're stubing send_file

        backup = Backup.new("backup42")
        Backup.expects(:[]).with(backup_filename).returns(backup)
        subject.expects(:send_file).with(backup.path)

        get :show, id: backup_filename
      end

      it "returns 404 when the backup does not exist" do
        Backup.expects(:[]).returns(nil)

        get :show, id: backup_filename

        response.should be_not_found
      end

    end

    describe ".destroy" do

      let(:b) { Backup.new(backup_filename) }

      it "removes the backup if found" do
        Backup.expects(:[]).with(backup_filename).returns(b)
        b.expects(:remove)
        xhr :delete, :destroy, id: backup_filename
        response.should be_success
      end

      it "doesn't remove the backup if not found" do
        Backup.expects(:[]).with(backup_filename).returns(nil)
        b.expects(:remove).never
        xhr :delete, :destroy, id: backup_filename
        response.should_not be_success
      end

    end

    describe ".logs" do

      it "preloads important data" do
        BackupRestore.expects(:operations_status).returns({})
        subject.expects(:store_preloaded).with("operations_status", "{}")

        BackupRestore.expects(:logs).returns([])
        subject.expects(:store_preloaded).with("logs", "[]")

        xhr :get, :logs, format: :html

        response.should be_success
      end
    end

    describe ".restore" do

      it "starts a restore" do
        BackupRestore.expects(:restore!).with(@admin.id, backup_filename, true)

        xhr :post, :restore, id: backup_filename

        response.should be_success
      end

    end

    describe ".rollback" do

      it "rolls back to previous working state" do
        BackupRestore.expects(:rollback!)

        xhr :get, :rollback

        response.should be_success
      end

    end

    describe ".readonly" do

      it "enables readonly mode" do
        Discourse.expects(:enable_readonly_mode)

        xhr :put, :readonly, enable: true

        response.should be_success
      end

      it "disables readonly mode" do
        Discourse.expects(:disable_readonly_mode)

        xhr :put, :readonly, enable: false

        response.should be_success
      end

    end

  end

end
