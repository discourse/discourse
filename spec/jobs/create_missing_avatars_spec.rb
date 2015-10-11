require 'rails_helper'

require_dependency 'jobs/scheduled/create_missing_avatars'

describe Jobs::CreateMissingAvatars do
  it "runs correctly without crashing" do
    Jobs::CreateMissingAvatars.new.execute(nil)
  end
end
