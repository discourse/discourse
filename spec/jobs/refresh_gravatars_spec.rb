require 'spec_helper'

require_dependency 'jobs/scheduled/refresh_gravatars'

describe Jobs::RefreshGravatars do
  it "runs correctly without crashing" do
    Jobs::RefreshGravatars.new.execute(nil)
  end
end
