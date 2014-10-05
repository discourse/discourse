require 'spec_helper'

describe Jobs::ExportCsvFile do

  context '.execute' do

    it 'raises an error when the entity is missing' do
      lambda { Jobs::ExportCsvFile.new.execute(user_id: "1") }.should raise_error(Discourse::InvalidParameters)
    end

  end
end

