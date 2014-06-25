require 'csv'
require_dependency 'jobs/base'

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

    context 'read csv file' do
      let(:csv_file) { File.new("#{Rails.root}/spec/fixtures/csv/discourse.csv") }
      let(:file) do
        ActionDispatch::Http::UploadedFile.new({ filename: 'discourse.csv', tempfile: csv_file })
      end

    end

  end

end
