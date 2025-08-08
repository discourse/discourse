# frozen_string_literal: true

RSpec.describe "Reports::AssociatedAccountsByProvider" do
  describe "associated_accounts_by_provider report" do
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }
    fab!(:user3) { Fabricate(:user) }

    before do
      Fabricate(:user_associated_account, user: user1, provider_name: "google_oauth2")
      Fabricate(:user_associated_account, user: user2, provider_name: "google_oauth2")
      Fabricate(:user_associated_account, user: user3, provider_name: "facebook")
    end

    it "returns data grouped by provider" do
      report = Report.find("associated_accounts_by_provider")

      expect(report.data.length).to eq(2)

      google_data = report.data.find { |d| d[:key] == "google_oauth2" }
      facebook_data = report.data.find { |d| d[:key] == "facebook" }

      expect(google_data[:y]).to eq(2)
      expect(facebook_data[:y]).to eq(1)
    end

    it "sorts data by count descending" do
      report = Report.find("associated_accounts_by_provider")

      expect(report.data.first[:y]).to be >= report.data.last[:y]
    end

    it "only includes active users" do
      user1.update!(active: false)

      report = Report.find("associated_accounts_by_provider")

      google_data = report.data.find { |d| d[:key] == "google_oauth2" }
      expect(google_data[:y]).to eq(1) # Only user2, not user1
    end
  end
end
