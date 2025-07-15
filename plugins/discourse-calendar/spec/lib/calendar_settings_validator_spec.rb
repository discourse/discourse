# frozen_string_literal: true
require "rails_helper"

describe CalendarSettingsValidator do
  def expect_invalid(val)
    expect(subject.valid_value?(val)).to eq(false)
  end

  def expect_valid(val)
    expect(subject.valid_value?(val)).to eq(true)
  end

  it "only allows valid HH:mm formats" do
    expect_invalid "markvanlan"
    expect_invalid "000:00"
    expect_invalid "00:000"
    expect_invalid "24:00"
    expect_invalid "00:60"
    expect_invalid "002:30"

    expect_valid ""
    expect_valid "00:00"
    expect_valid "23:00"
    expect_valid "00:59"
    expect_valid "23:59"
    expect_valid "06:40"
  end
end
