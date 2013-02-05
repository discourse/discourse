require 'spec_helper'
require 'import/import'

class AdapterX < Import::Adapter::Base; end

class Adapter1 < Import::Adapter::Base; end
class Adapter2 < Import::Adapter::Base; end
class Adapter3 < Import::Adapter::Base; end

describe Import do
  describe "is_import_running?" do
    it "should return true when an import is in progress" do
      $redis.stubs(:get).with(Import.import_running_key).returns('1')
      Import.is_import_running?.should be_true
    end

    it "should return false when an import is not happening" do
      $redis.stubs(:get).with(Import.import_running_key).returns('0')
      Import.is_import_running?.should be_false
    end

    it "should return false when an import has never been run" do
      $redis.stubs(:get).with(Import.import_running_key).returns(nil)
      Import.is_import_running?.should be_false
    end
  end

  describe 'add_import_adapter' do
    it "should return true" do
      Import.clear_adapters
      Import.add_import_adapter(AdapterX, '20130110121212', ['users']).should be_true
    end
  end

  describe 'adapters_for_version' do
    it "should return an empty Hash when there are no adapters" do
      Import.clear_adapters
      Import.adapters_for_version('1').should == {}
    end

    context 'when there are some adapters' do
      before do
        Import.clear_adapters
        Import.add_import_adapter(Adapter1, '10', ['users'])
        Import.add_import_adapter(Adapter2, '20', ['users'])
        Import.add_import_adapter(Adapter3, '30', ['users'])
      end

      it "should return no adapters when the version is newer than all adapters" do
        Import.adapters_for_version('31')['users'].should have(0).adapters
      end

      it "should return adapters that are newer than the given version" do
        Import.adapters_for_version('12')['users'].should have(2).adapters
        Import.adapters_for_version('22')['users'].should have(1).adapters
      end

      it "should return the adapters in order" do
        adapters = Import.adapters_for_version('1')['users']
        adapters[0].should be_a(Adapter1)
        adapters[1].should be_a(Adapter2)
        adapters[2].should be_a(Adapter3)
      end
    end
  end
end