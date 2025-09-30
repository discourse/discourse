# frozen_string_literal: true

describe SiteSetting do
  before { SiteSetting.calendar_enabled = true }

  it "has the correct default value" do
    expect(SiteSetting.calendar_first_day_of_week).to eq("monday")
  end

  it "accepts valid enum values" do
    expect { SiteSetting.calendar_first_day_of_week = "saturday" }.not_to raise_error
    expect { SiteSetting.calendar_first_day_of_week = "sunday" }.not_to raise_error
    expect { SiteSetting.calendar_first_day_of_week = "monday" }.not_to raise_error
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
