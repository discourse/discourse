# frozen_string_literal: true

RSpec.describe UsersController do
  fab!(:user)

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  describe "event reminder preferences" do
    it "serializes the default and saves each channel through user preferences" do
      sign_in(user)
      get "/u/#{user.username}.json"
      expect(response.parsed_body.dig("user", "user_option", "event_reminder_preference")).to eq(
        "personal_message",
      )

      %w[personal_message none notification].each do |channel|
        put "/u/#{user.username}.json", params: { event_reminder_preference: channel }
        expect(response.status).to eq(200)
        expect(user.user_option.reload.event_reminder_preference).to eq(channel)
      end
    end

    it "rejects invalid channels without changing the option" do
      sign_in(user)
      put "/u/#{user.username}.json", params: { event_reminder_preference: "email" }
      expect(response.status).to eq(422)
      expect(user.user_option.reload.event_reminder_preference).to eq("personal_message")
    end

    it "requires login" do
      put "/u/#{user.username}.json", params: { event_reminder_preference: "none" }
      expect(response.status).to eq(403)
    end

    it "prevents editing another user's option" do
      sign_in(Fabricate(:user))
      put "/u/#{user.username}.json", params: { event_reminder_preference: "none" }
      expect(response.status).to eq(403)
      expect(user.user_option.reload.event_reminder_preference).to eq("personal_message")
    end
  end
end
