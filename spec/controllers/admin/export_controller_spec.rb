require 'spec_helper'

describe Admin::ExportController do
  it "is a subclass of AdminController" do
    (Admin::ExportController < Admin::AdminController).should be_true
  end

  context 'while logged in as an admin' do
    before do
      @user = log_in(:admin)
    end

    describe "create" do
      it "should start an export job" do
        Jobs::Exporter.any_instance.expects(:execute).returns(true)
        xhr :post, :create
      end

      it "should return a job id" do
        job_id = 'abc123'
        Jobs.stubs(:enqueue).returns( job_id )
        xhr :post, :create
        json = JSON.parse(response.body)
        json.should have_key('job_id')
        json['job_id'].should == job_id
      end

      shared_examples_for "when export should not be started" do
        it "should return an error" do
          xhr :post, :create
          json = JSON.parse(response.body)
          json['failed'].should_not be_nil
          json['message'].should_not be_nil
        end

        it "should not start an export job" do
          Jobs::Exporter.any_instance.expects(:start_export).never
          xhr :post, :create
        end
      end

      context "when an export is already running" do
        before do
          Export.stubs(:is_export_running?).returns( true )
        end
        it_should_behave_like "when export should not be started"
      end

      context "when an import is currently running" do
        before do
          Import.stubs(:is_import_running?).returns( true )
        end
        it_should_behave_like "when export should not be started"
      end
    end
  end
end
