# frozen_string_literal: true

RSpec.describe Jobs::ChatPeriodicalUpdates do
  it "works" do
    # does not blow up, no mocks, everything is called
    Jobs::ChatPeriodicalUpdates.new.execute(nil)
  end
end
