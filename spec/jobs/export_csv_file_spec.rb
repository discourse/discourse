require 'spec_helper'

describe Jobs::ExportCsvFile do

  context '.execute' do
    it 'raises an error when the entity is missing' do
      lambda { Jobs::ExportCsvFile.new.execute(user_id: "1") }.should raise_error(Discourse::InvalidParameters)
    end
  end

  let :user_list_header do
    Jobs::ExportCsvFile.new.get_header('user')
  end

  let :user_list_export do
    Jobs::ExportCsvFile.new.user_list_export
  end

  def to_hash(row)
    Hash[*user_list_header.zip(row).flatten]
  end

  it 'exports sso data' do
    SiteSetting.enable_sso = true
    user = Fabricate(:user)
    user.create_single_sign_on_record(external_id: "123", last_payload: "xxx", external_email: 'test@test.com')

    user = to_hash(user_list_export.find{|u| u[0] == user.id})

    user["external_id"].should == "123"
    user["external_email"].should == "test@test.com"
  end
end
