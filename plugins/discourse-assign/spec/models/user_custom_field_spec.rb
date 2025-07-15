# frozen_string_literal: true

require "rails_helper"

RSpec.describe UserCustomField do
  before { SiteSetting.assign_enabled = true }

  let(:field_name) { PendingAssignsReminder::REMINDERS_FREQUENCY }
  let(:new_field) { UserCustomField.new(name: field_name, user_id: 1) }

  it "coerces the value to be an integer" do
    new_field.value = "DROP TABLE USERS;"

    new_field.save!
    saved_field = new_field.reload

    expect(saved_field.value).to eq("0")
  end
end
