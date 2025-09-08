# frozen_string_literal: true

RSpec.describe "Reports::AssociatedAccountsByProvider" do
  describe "associated_accounts_by_provider report" do
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }
    fab!(:user3) { Fabricate(:user) }
    fab!(:user4) { Fabricate(:user) } # User with no associated accounts
    fab!(:user5) { Fabricate(:user) } # User with disabled provider
    fab!(:user6) { Fabricate(:user) } # User with DiscourseConnect

    before do
      # Mock enabled authenticators to only include specific providers
      google_auth = instance_double("Auth::Authenticator", name: "google_oauth2")
      facebook_auth = instance_double("Auth::Authenticator", name: "facebook")
      github_auth = instance_double("Auth::Authenticator", name: "github") # Provider with no users

      allow(Discourse).to receive(:enabled_authenticators).and_return(
        [google_auth, facebook_auth, github_auth],
      )

      SiteSetting.enable_discourse_connect = false

      Fabricate(:user_associated_account, user: user1, provider_name: "google_oauth2")
      Fabricate(:user_associated_account, user: user2, provider_name: "google_oauth2")
      Fabricate(:user_associated_account, user: user3, provider_name: "facebook")
      Fabricate(:user_associated_account, user: user5, provider_name: "twitter") # twitter is not enabled

      # Create a SingleSignOnRecord for user6
      SingleSignOnRecord.create!(
        user_id: user6.id,
        external_id: "discourse_connect_user",
        last_payload: "test",
      )
    end

    it "returns data grouped by provider, enabled providers only" do
      report = Report.find("associated_accounts_by_provider")

      google_data = report.data.find { |d| d[:key] == "google_oauth2" }
      facebook_data = report.data.find { |d| d[:key] == "facebook" }
      github_data = report.data.find { |d| d[:key] == "github" }
      twitter_data = report.data.find { |d| d[:key] == "twitter" }

      expect(google_data[:count]).to eq(2)
      expect(facebook_data[:count]).to eq(1)
      # GitHub should appear with 0 users since it's enabled
      expect(github_data[:count]).to eq(0)
      # Twitter should not appear since it's not in enabled authenticators
      expect(twitter_data).to be_nil
    end

    it "includes enabled providers with zero users" do
      report = Report.find("associated_accounts_by_provider")

      github_data = report.data.find { |d| d[:key] == "github" }
      expect(github_data).to be_present
      expect(github_data[:count]).to eq(0)
    end

    it "includes total users count" do
      report = Report.find("associated_accounts_by_provider")

      total_data = report.data.find { |d| d[:key] == "total_users" }
      expect(total_data).to be_present
      expect(total_data[:provider]).to eq("Total active user accounts")
      expect(total_data[:count]).to be >= 4 # At least our test users
    end

    it "includes users with no associated accounts from enabled providers" do
      report = Report.find("associated_accounts_by_provider")

      no_accounts_data = report.data.find { |d| d[:key] == "no_accounts" }
      expect(no_accounts_data).to be_present
      expect(no_accounts_data[:provider]).to eq("No associated accounts")
      # user4 has no accounts, user5 has twitter (disabled), so both should be counted
      expect(no_accounts_data[:count]).to be >= 2
    end

    it "sorts data by count descending" do
      report = Report.find("associated_accounts_by_provider")

      expect(report.data.first[:count]).to be >= report.data.last[:count]
    end

    it "only includes active users" do
      user1.update!(active: false)

      report = Report.find("associated_accounts_by_provider")

      google_data = report.data.find { |d| d[:key] == "google_oauth2" }
      expect(google_data[:count]).to eq(1) # Only user2, not user1
    end

    it "calculates users without enabled provider accounts correctly" do
      Fabricate(:user)
      Fabricate(:user)

      report = Report.find("associated_accounts_by_provider")

      total_data = report.data.find { |d| d[:key] == "total_users" }
      no_accounts_data = report.data.find { |d| d[:key] == "no_accounts" }

      # 3 users with enabled provider accounts (user1, user2, user3)
      # 4+ users without enabled provider accounts (user4, user5 with disabled twitter plus the two new users)
      expect(total_data[:count]).to be >= 7
      expect(no_accounts_data[:count]).to be >= 4
    end

    it "handles case when no authenticators are enabled" do
      allow(Discourse).to receive(:enabled_authenticators).and_return([])

      report = Report.find("associated_accounts_by_provider")

      # Should only have total users and no accounts entries
      provider_entries = report.data.reject { |d| %w[total_users no_accounts].include?(d[:key]) }
      expect(provider_entries).to be_empty

      total_data = report.data.find { |d| d[:key] == "total_users" }
      no_accounts_data = report.data.find { |d| d[:key] == "no_accounts" }

      expect(total_data[:count]).to be >= 5
      expect(no_accounts_data[:count]).to eq(total_data[:count])
    end

    it "includes all enabled providers even with mixed zero and non-zero counts" do
      report = Report.find("associated_accounts_by_provider")

      # Should have 3 enabled providers + total_users + no_accounts = 5 entries
      provider_entries =
        report.data.select { |d| %w[google_oauth2 facebook github].include?(d[:key]) }
      expect(provider_entries.length).to eq(3)

      # Verify we have entries with both zero and non-zero counts
      counts = provider_entries.map { |entry| entry[:count] }
      expect(counts).to include(0) # GitHub
      expect(counts).to include(1) # Facebook
      expect(counts).to include(2) # Google
    end

    context "with DiscourseConnect enabled" do
      before do
        SiteSetting.discourse_connect_url = "https://example.com/sso"
        SiteSetting.enable_discourse_connect = true
      end

      it "includes DiscourseConnect user count and users without DiscourseConnect records" do
        report = Report.find("associated_accounts_by_provider")

        discourse_connect_data = report.data.find { |d| d[:key] == "discourse_connect" }
        expect(discourse_connect_data).to be_present
        expect(discourse_connect_data[:count]).to eq(1) # user6

        # Only user6 has an SSO record
        # The users without accounts should be total (6) - the one user with an SSO record
        no_accounts_data = report.data.find { |d| d[:key] == "no_accounts" }

        expect(no_accounts_data[:count]).to eq(5)

        total_data = report.data.find { |d| d[:key] == "total_users" }
        expect(total_data).not_to be_present
      end
    end
  end
end
