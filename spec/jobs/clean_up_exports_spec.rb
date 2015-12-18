require 'rails_helper'

require_dependency 'jobs/scheduled/clean_up_exports'

describe Jobs::CleanUpExports do
  it "runs correctly without crashing" do
    Jobs::CleanUpExports.new.execute(nil)
  end
end
