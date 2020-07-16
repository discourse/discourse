# frozen_string_literal: true

require 'rails_helper'

describe UserEmail do
  fab!(:user) { Fabricate(:user) }

  context "validation" do
    it "allows only one primary email" do
      expect {
        Fabricate(:secondary_email, user: user, primary: true)
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "allows multiple secondary emails" do
      events = DiscourseEvent.track_events {
        Fabricate(:secondary_email, user: user, primary: false)
        Fabricate(:secondary_email, user: user, primary: false)
      }

      expect(user.user_emails.count).to eq 3
      expect(events.count).to eq 2

      event = events.first
      expect(event[:event_name]).to eq(:user_updated)
      expect(event[:params].first).to eq(user)
    end

    it "does not allow an invalid email" do
      user_email = Fabricate.build(:user_email, user: user, email: "asjdaiosd")
      expect(user_email.valid?).to eq(false)
      expect(user_email.errors.details[:email].first[:error]).to eq(I18n.t("user.email.invalid"))
    end
  end

  context "indexes" do
    it "allows only one primary email" do
      expect {
        Fabricate.build(:secondary_email, user: user, primary: true).save(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows multiple secondary emails" do
      Fabricate.build(:secondary_email, user: user, primary: false).save(validate: false)
      Fabricate.build(:secondary_email, user: user, primary: false).save(validate: false)
      expect(user.user_emails.count).to eq 3
    end
  end
end
