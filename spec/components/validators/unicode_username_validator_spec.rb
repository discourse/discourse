# frozen_string_literal: true

require 'rails_helper'

describe UnicodeUsernameValidator do
  subject { described_class.new }

  it "disallows Unicode usernames when external system avatars are disabled" do
    SiteSetting.external_system_avatars_enabled = false

    expect(subject.valid_value?("t")).to eq(false)
    expect(subject.error_message).to eq(I18n.t("site_settings.errors.unicode_usernames_avatars"))

    expect(subject.valid_value?("f")).to eq(true)
    expect(subject.error_message).to be_blank
  end

  it "allows Unicode usernames when external system avatars are enabled" do
    SiteSetting.external_system_avatars_enabled = true

    expect(subject.valid_value?("t")).to eq(true)
    expect(subject.error_message).to be_blank

    expect(subject.valid_value?("f")).to eq(true)
    expect(subject.error_message).to be_blank
  end
end
