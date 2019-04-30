# frozen_string_literal: true

require 'rails_helper'

describe UnicodeUsernameWhitelistValidator do
  subject { described_class.new }

  it "allows an empty whitelist" do
    expect(subject.valid_value?("")).to eq(true)
    expect(subject.error_message).to be_blank
  end

  it "disallows leading and trailing slashes" do
    expected_error = I18n.t("site_settings.errors.unicode_username_whitelist.leading_trailing_slash")

    expect(subject.valid_value?("/foo/")).to eq(false)
    expect(subject.error_message).to eq(expected_error)

    expect(subject.valid_value?("foo/")).to eq(true)
    expect(subject.error_message).to be_blank

    expect(subject.valid_value?("/foo")).to eq(true)
    expect(subject.error_message).to be_blank

    expect(subject.valid_value?("f/o/o")).to eq(true)
    expect(subject.error_message).to be_blank

    expect(subject.valid_value?("/foo/i")).to eq(false)
    expect(subject.error_message).to eq(expected_error)
  end

  it "detects invalid regular expressions" do
    expected_error = I18n.t("site_settings.errors.unicode_username_whitelist.regex_invalid", error: "")

    expect(subject.valid_value?("\\p{Foo}")).to eq(false)
    expect(subject.error_message).to start_with(expected_error)
  end
end
