require 'rails_helper'

require_dependency 'jobs/scheduled/clean_up_uploads'

describe Jobs::CleanUpUploads do
  it "runs correctly without crashing" do
    SiteSetting.clean_up_uploads = true
    Jobs::CleanUpUploads.new.execute(nil)
  end
end
