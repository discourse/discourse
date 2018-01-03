require 'rails_helper'
require_dependency 'jobs/scheduled/periodical_updates'

describe Jobs::PeriodicalUpdates do

  it "works" do

    # does not blow up, no mocks, everything is called
    Jobs::PeriodicalUpdates.new.execute(nil)
  end

end
