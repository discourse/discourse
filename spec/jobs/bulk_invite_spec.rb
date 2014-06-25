require 'csv'
require_dependency 'system_message'

describe Jobs::BulkInvite do

  context '.execute' do

    it 'raises an error when the filename is missing' do
      lambda { Jobs::InviteEmail.new.execute(identifier: '46-discoursecsv', chunks: '1') }.should raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when the identifier is missing' do
      lambda { Jobs::InviteEmail.new.execute(filename: 'discourse.csv', chunks: '1') }.should raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when the chunks is missing' do
      lambda { Jobs::InviteEmail.new.execute(filename: 'discourse.csv', identifier: '46-discoursecsv') }.should raise_error(Discourse::InvalidParameters)
    end

  end

end
