# frozen_string_literal: true

describe CalendarCustomFieldsValidator do
  def expect_invalid(val)
    expect(subject.valid_value?(val)).to eq(false)
    expect(subject.error_message).to be_present
  end

  def expect_valid(val)
    expect(subject.valid_value?(val)).to eq(true)
  end

  def message_for(val)
    subject.valid_value?(val)
    subject.error_message
  end

  it "allows an empty value and unique, unreserved, well-formed names" do
    expect_valid ""
    expect_valid "venue"
    expect_valid "venue|seat_count"
    expect_valid "dress_CODE|live-stream|q.and.a"
  end

  it "rejects malformed names (leading, trailing or repeated separators)" do
    expect_invalid "_secret"
    expect_invalid "venue|_secret"
    expect_invalid "trailing_"
    expect_invalid "double__underscore"
    expect_invalid "has space"
  end

  it "rejects names that collide once normalized" do
    expect_invalid "field-aa|field_aa"
    expect_invalid "field1|field_1"
    expect_invalid "Venue|venue"
  end

  it "rejects names reserved by built-in event options" do
    expect_invalid "name"
    expect_invalid "venue|url"
    expect_invalid "all_day"
    expect_invalid "max-attendees"
  end

  it "reports every problem at once, naming each offending field" do
    message = message_for("_secret|Venue|venue|url")

    expect(message).to include("_secret") # malformed
    expect(message).to include("Venue").and include("venue") # collide once normalized
    expect(message).to include("url") # reserved
  end
end
