require "spec_helper"

describe Admin::ExportCsvController do

  it "is a subclass of AdminController" do
    (Admin::ExportCsvController < Admin::AdminController).should == true
  end

  let(:export_filename) { "export_b6a2bc87.csv" }

  context "while logged in as an admin" do

    before { @admin = log_in(:admin) }

    describe ".download" do

      it "uses send_file to transmit the export file" do
        controller.stubs(:render)
        export = ExportCsv.new()
        ExportCsv.expects(:get_download_path).with(export_filename).returns(export)
        subject.expects(:send_file).with(export)
        get :show, id: export_filename
      end

      it "returns 404 when the export file does not exist" do
        ExportCsv.expects(:get_download_path).returns(nil)
        get :show, id: export_filename
        response.should be_not_found
      end

    end

  end

end
