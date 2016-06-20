require 'rails_helper'

require_dependency 'jobs/scheduled/clean_up_uploads'

describe Jobs::CleanUpUploads do

  before do
    Upload.destroy_all
    SiteSetting.clean_up_uploads = true
    SiteSetting.clean_orphan_uploads_grace_period_hours = 1
  end

  it "deletes orphan uploads" do
    Fabricate(:upload, created_at: 2.hours.ago)

    expect(Upload.count).to be(1)

    Jobs::CleanUpUploads.new.execute(nil)

    expect(Upload.count).to be(0)
  end

end
