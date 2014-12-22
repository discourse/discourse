require "spec_helper"

describe ExportCsvController do

  let(:export_filename) { "export_b6a2bc87.csv" }


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
        controller.stubs(:render)
        export = ExportCsv.new()
        ExportCsv.expects(:get_download_path).with(export_filename).returns(export)
        subject.expects(:send_file).with(export)
        get :show, entity: "username", file_id: export_filename
        response.should be_success
      end

      it "returns 404 when the normal user tries to access admin export file" do
        controller.stubs(:render)
        get :show, entity: "system", file_id: export_filename
        response.should_not be_success
      end

      it "returns 404 when the export file does not exist" do
        ExportCsv.expects(:get_download_path).returns(nil)
        get :show, entity: "username", file_id: export_filename
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
        controller.stubs(:render)
        export = ExportCsv.new()
        ExportCsv.expects(:get_download_path).with(export_filename).returns(export)
        subject.expects(:send_file).with(export)
        get :show, entity: "system", file_id: export_filename
        response.should be_success
      end

      it "returns 404 when the export file does not exist" do
        ExportCsv.expects(:get_download_path).returns(nil)
        get :show, entity: "system", file_id: export_filename
        response.should be_not_found
      end
    end
  end

end
