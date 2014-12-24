require "spec_helper"

describe ExportCsvController do
  let(:export_filename) { "export_999.csv" }


  context "while logged in as normal user" do
    before { @user = log_in(:user) }

    describe ".export_entity" do
      it "enqueues export job" do
        Jobs.expects(:enqueue).with(:export_csv_file, has_entries(entity: "user_archive", user_id: @user.id))
        xhr :post, :export_entity, entity: "user_archive", entity_type: "user"
        response.should be_success
      end

      it "returns 404 when normal user tries to export admin entity" do
        xhr :post, :export_entity, entity: "staff_action", entity_type: "admin"
        response.should_not be_success
      end
    end

    describe ".download" do
      it "uses send_file to transmit the export file" do
        file = CsvExportLog.create(export_type: "user", user_id: @user.id)
        file_name = "export_#{file.id}.csv"
        controller.stubs(:render)
        export = CsvExportLog.new()
        CsvExportLog.expects(:get_download_path).with(file_name).returns(export)
        subject.expects(:send_file).with(export)
        get :show, id: file_name
        response.should be_success
      end

      it "returns 404 when the user tries to export another user's csv file" do
        get :show, id: export_filename
        response.should be_not_found
      end

      it "returns 404 when the export file does not exist" do
        CsvExportLog.expects(:get_download_path).returns(nil)
        get :show, id: export_filename
        response.should be_not_found
      end
    end
  end


  context "while logged in as an admin" do
    before { @admin = log_in(:admin) }

    describe ".export_entity" do
      it "enqueues export job" do
        Jobs.expects(:enqueue).with(:export_csv_file, has_entries(entity: "staff_action", user_id: @admin.id))
        xhr :post, :export_entity, entity: "staff_action", entity_type: "admin"
        response.should be_success
      end
    end

    describe ".download" do
      it "uses send_file to transmit the export file" do
        file = CsvExportLog.create(export_type: "admin", user_id: @admin.id)
        file_name = "export_#{file.id}.csv"
        controller.stubs(:render)
        export = CsvExportLog.new()
        CsvExportLog.expects(:get_download_path).with(file_name).returns(export)
        subject.expects(:send_file).with(export)
        get :show, id: file_name
        response.should be_success
      end

      it "returns 404 when the export file does not exist" do
        CsvExportLog.expects(:get_download_path).returns(nil)
        get :show, id: export_filename
        response.should be_not_found
      end
    end
  end

end
