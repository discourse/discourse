# frozen_string_literal: true

RSpec.describe Jobs::Chat::PeriodicalUpdates do
  it "completes without errors" do
    # does not blow up, no mocks, everything is called
    Jobs::Chat::PeriodicalUpdates.new.execute(nil)
  end
end
