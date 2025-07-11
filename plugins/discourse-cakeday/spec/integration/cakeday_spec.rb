# frozen_string_literal: true

require "rails_helper"

describe "Anniversaries and Birthdays" do
  describe "when not logged in" do
    it "should return the right response" do
      get "/cakeday/anniversaries.json"
      expect(response.status).to eq(403)
    end
  end

  describe "when logged in" do
    let(:time) { Time.zone.local(2016, 9, 30) }
    let(:current_user) { Fabricate(:user, created_at: time - 10.days) }

    before { sign_in(current_user) }

    it "should return 404 when viewing anniversaries and cakeday_enabled is false" do
      SiteSetting.cakeday_enabled = false

      get "/cakeday/anniversaries.json"
      expect(response.status).to eq(404)
    end

    it "should return 404 when viewing birthdays and cakeday_birthday_enabled is false" do
      SiteSetting.cakeday_birthday_enabled = false

      get "/cakeday/birthdays.json"
      expect(response.status).to eq(404)
    end

    describe "when viewing anniversaries" do
      it "should return the right payload" do
        freeze_time(time) do
          created_at = time - 1.year

          user1 = Fabricate(:user, created_at: created_at - 2.year)
          user2 = Fabricate(:user, created_at: created_at - 1.day)
          user3 = Fabricate(:user, created_at: created_at)
          user4 = Fabricate(:user, created_at: created_at + 1.day)
          user5 = Fabricate(:user, created_at: created_at + 2.day)
          user6 = Fabricate(:user, created_at: created_at + 1.year)

          hidden_user = Fabricate(:user, created_at: created_at - 1.year)
          hidden_user.user_option.update!(hide_profile: true)

          get "/cakeday/anniversaries.json", params: { month: time.month }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to eq [user2.id, user1.id, user3.id]

          get "/cakeday/anniversaries.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to eq [user1.id, user3.id]

          get "/cakeday/anniversaries.json", params: { filter: "tomorrow" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to eq [user4.id]

          get "/cakeday/anniversaries.json", params: { filter: "upcoming" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to eq [user5.id]
        end
      end

      it "should account for the current user's timezone" do
        # Asia/Calcutta is +5.5 hours from UTC
        current_user.user_option.update!(timezone: "Asia/Calcutta")

        freeze_time(time) do
          created_at = time - 1.year

          user1 = Fabricate(:user, created_at: created_at + 5.hours)
          user2 = Fabricate(:user, created_at: created_at + 18.hours + 20.minutes)
          user3 = Fabricate(:user, created_at: created_at + 18.hours + 40.minutes)
          user4 = Fabricate(:user, created_at: created_at + 1.day + 2.hours)

          hidden_user = Fabricate(:user, created_at: created_at - 1.year)
          hidden_user.user_option.update!(hide_profile: true)

          get "/cakeday/anniversaries.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to contain_exactly(user1.id, user2.id)

          get "/cakeday/anniversaries.json", params: { filter: "tomorrow" }

          body = JSON.parse(response.body)
          expect(body["anniversaries"].map { |u| u["id"] }).to contain_exactly(user3.id, user4.id)
        end
      end
    end

    describe "when viewing birthdays" do
      let(:time) { Time.zone.local(2016, 9, 30) }

      it "should return the right payload" do
        freeze_time(time) do
          user1 = Fabricate(:user, date_of_birth: "1904-9-28")
          user2 = Fabricate(:user, date_of_birth: "1904-9-29")
          user3 = Fabricate(:user, date_of_birth: "1904-9-30")
          user4 = Fabricate(:user, date_of_birth: "1904-10-1")
          user5 = Fabricate(:user, date_of_birth: "1904-10-2")

          get "/cakeday/birthdays.json", params: { month: time.month }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user1.id, user2.id, user3.id]

          get "/cakeday/birthdays.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user3.id]

          get "/cakeday/birthdays.json", params: { filter: "tomorrow" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user4.id]

          get "/cakeday/birthdays.json", params: { filter: "upcoming" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user5.id]
        end
      end

      it "respects the prioritize_username_in_ux site setting" do
        freeze_time(time) do
          dob = "1904-9-30"
          user1 = Fabricate(:user, username: "alpha_zeta", name: "Zeta Alpha", date_of_birth: dob)
          user2 = Fabricate(:user, username: "zeta_alpha", name: "Alpha Zeta", date_of_birth: dob)
          user3 = Fabricate(:user, username: "beta_omega", name: "", date_of_birth: dob)

          SiteSetting.prioritize_username_in_ux = true

          get "/cakeday/birthdays.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user1.id, user3.id, user2.id]

          SiteSetting.prioritize_username_in_ux = false

          get "/cakeday/birthdays.json", params: { filter: "today" }

          body = JSON.parse(response.body)
          expect(body["birthdays"].map { |u| u["id"] }).to eq [user2.id, user3.id, user1.id]
        end
      end
    end
  end
end
