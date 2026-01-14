# frozen_string_literal: true

RSpec.describe "Custom timezones initializer" do
  it "maps IST to Asia/Kolkata" do
    expect(ActiveSupport::TimeZone["IST"].tzinfo).to eq(
      ActiveSupport::TimeZone["Asia/Kolkata"].tzinfo,
    )
  end
end
