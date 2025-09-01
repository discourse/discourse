# frozen_string_literal: true

require "rails_helper"

describe SiteSetting do
  before { SiteSetting.calendar_enabled = true }

  it "has the correct default value" do
    expect(SiteSetting.calendar_first_day_of_week).to eq("Monday")
  end

  it "accepts valid enum values" do
    expect { SiteSetting.calendar_first_day_of_week = "Saturday" }.not_to raise_error
    expect { SiteSetting.calendar_first_day_of_week = "Sunday" }.not_to raise_error
    expect { SiteSetting.calendar_first_day_of_week = "Monday" }.not_to raise_error
  end

  it "rejects invalid enum values" do
    expect { SiteSetting.calendar_first_day_of_week = "Tuesday" }.to raise_error(
      Discourse::InvalidParameters,
    )
    expect { SiteSetting.calendar_first_day_of_week = "Friday" }.to raise_error(
      Discourse::InvalidParameters,
    )
    expect { SiteSetting.calendar_first_day_of_week = "Invalid" }.to raise_error(
      Discourse::InvalidParameters,
    )
  end
end
