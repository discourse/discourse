require 'spec_helper'
require 'import/adapter/base'

describe Import::Adapter::Base do

  describe 'the base implementation' do
    let(:adapter) { Import::Adapter::Base.new }

    describe 'apply_to_column_names' do
      it 'should return the column names passed in' do
        cols = ['first', 'second']
        adapter.apply_to_column_names('table_name', cols).should == cols
      end
    end

    describe 'apply_to_row' do
      it 'should return the row passed in' do
        row = [1,2,3,4]
        adapter.apply_to_row('table_name', row).should == row
      end
    end
  end

end