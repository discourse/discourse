require 'spec_helper'
require_dependency 'directory_helper'

describe DirectoryHelper do
  class DummyClass
    include DirectoryHelper
  end
  let(:helper) { DummyClass.new }

  before do
    helper.tmp_directory('prefix')
    helper.tmp_directory('other_prefix')
  end

  after do
    helper.remove_tmp_directory('prefix')
    helper.remove_tmp_directory('other_prefix')
  end

  describe '#tmp_directory' do
    it 'is memoized by prefix' do
      helper.tmp_directory('prefix').should eq(helper.tmp_directory('prefix'))
      helper.tmp_directory('prefix').should_not eq(helper.tmp_directory('other_prefix'))
    end
  end

  describe '#remove_tmp_directory' do
    it 'removes the prefixed directory from the filesystem' do
      tmp_directory = helper.tmp_directory('prefix')
      helper.remove_tmp_directory('prefix')

      Dir[tmp_directory].should_not be_present
    end
  end
end
