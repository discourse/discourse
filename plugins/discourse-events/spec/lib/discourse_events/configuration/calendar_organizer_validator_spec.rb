# frozen_string_literal: true

RSpec.describe DiscourseEvents::Configuration::CalendarOrganizerValidator do
  subject(:validator) { described_class.new }

  it "allows an empty setting or a standalone mailbox" do
    expect(validator.valid_value?("")).to eq(true)
    expect(validator.valid_value?("calendar@example.com")).to eq(true)
  end

  it "rejects malformed addresses and known inbound routes" do
    group = Fabricate(:group, incoming_email: "group@example.com")
    category = Fabricate(:category, email_in: "category@example.com")
    SiteSetting.reply_by_email_address = "replies+%{reply_key}@example.com"

    [
      "invalid",
      "calendar@example.com\r\nATTENDEE:evil",
      group.incoming_email,
      category.email_in,
      "replies+calendar@example.com",
    ].each { |address| expect(validator.valid_value?(address)).to eq(false) }
  end
end
