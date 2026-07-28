# frozen_string_literal: true

describe DateSettingValidator do
  subject(:validator) { described_class.new }

  it "accepts blank and ISO 8601 date values" do
    expect(validator.valid_value?("")).to eq(true)
    expect(validator.valid_value?(nil)).to eq(true)
    expect(validator.valid_value?("2026-07-01")).to eq(true)
  end

  it "rejects datetimes and non-ISO date values" do
    expect(validator.valid_value?("2026-07-01T00:00:00Z")).to eq(false)
    expect(validator.valid_value?("01/07/2026")).to eq(false)
    expect(validator.valid_value?("2026-02-30")).to eq(false)
  end
end
