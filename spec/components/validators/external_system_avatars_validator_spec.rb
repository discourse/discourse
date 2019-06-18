# frozen_string_literal: true

require 'rails_helper'

describe ExternalSystemAvatarsValidator do
  subject { described_class.new }

  it "disallows disabling external system avatars when Unicode usernames are enabled" do
    SiteSetting.unicode_usernames = true

    expect(subject.valid_value?("f")).to eq(false)
    expect(subject.error_message).to eq(I18n.t("site_settings.errors.unicode_usernames_avatars"))

    expect(subject.valid_value?("t")).to eq(true)
    expect(subject.error_message).to be_blank
  end

  it "allows disabling external system avatars when Unicode usernames are disabled" do
    SiteSetting.unicode_usernames = false

    expect(subject.valid_value?("t")).to eq(true)
    expect(subject.error_message).to be_blank

    expect(subject.valid_value?("f")).to eq(true)
    expect(subject.error_message).to be_blank
  end
end
