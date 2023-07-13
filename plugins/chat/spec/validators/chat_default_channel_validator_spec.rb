# frozen_string_literal: true

require "rails_helper"

describe Chat::DefaultChannelValidator do
  fab!(:channel) { Fabricate(:category_channel) }

  it "provides an error message" do
    validator = described_class.new
    expect(validator.error_message).to eq(I18n.t("site_settings.errors.chat_default_channel"))
  end

  it "returns true if public channel id" do
    validator = described_class.new
    expect(validator.valid_value?(channel.id)).to eq(true)
  end

  it "returns true if empty string" do
    validator = described_class.new
    expect(validator.valid_value?("")).to eq(true)
  end

  it "returns false if not a public channel" do
    validator = described_class.new
    channel.destroy!
    expect(validator.valid_value?(channel.id)).to eq(false)
  end
end
