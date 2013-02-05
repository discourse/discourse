require 'spec_helper'
require 'export/export'

describe Export do
  describe '#current_schema_version' do
    it "should return the latest migration version" do
      Export.current_schema_version.should == User.exec_sql("select max(version) as max from schema_migrations")[0]["max"]
    end
  end

  describe "models_included_in_export" do
    it "should include the user model" do
      Export.models_included_in_export.map(&:name).should include('User')
    end

    it "should not include the message bus model" do
      Export.models_included_in_export.map(&:name).should_not include('MessageBus')
    end
  end

  describe "is_export_running?" do
    it "should return true when an export is in progress" do
      $redis.stubs(:get).with(Export.export_running_key).returns('1')
      Export.is_export_running?.should be_true
    end

    it "should return false when an export is not happening" do
      $redis.stubs(:get).with(Export.export_running_key).returns('0')
      Export.is_export_running?.should be_false
    end

    it "should return false when an export has never been run" do
      $redis.stubs(:get).with(Export.export_running_key).returns(nil)
      Export.is_export_running?.should be_false
    end
  end
end