require 'spec_helper'
require 'csv'

describe Jobs::BulkInvite do

  context '.execute' do

    it 'raises an error when the filename is missing' do
      lambda { Jobs::BulkInvite.new.execute(identifier: '46-discoursecsv', chunks: '1') }.should raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when the identifier is missing' do
      lambda { Jobs::BulkInvite.new.execute(filename: 'discourse.csv', chunks: '1') }.should raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when the chunks is missing' do
      lambda { Jobs::BulkInvite.new.execute(filename: 'discourse.csv', identifier: '46-discoursecsv') }.should raise_error(Discourse::InvalidParameters)
    end

    context 'read csv file' do
      Jobs::BulkInvite.any_instance.stubs(:get_csv_path).with(filename: 'discourse.csv', identifier: '46-discoursecsv', chunks: '1')
      Jobs::BulkInvite.new.execute(filename: 'discourse.csv', identifier: '46-discoursecsv', chunks: '1')

    end

  end

end
