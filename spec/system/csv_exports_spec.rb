# frozen_string_literal: true

RSpec.describe "CSV Exports", type: :system do
  fab!(:admin) { Fabricate(:admin) }
  let(:csv_export_pm_page) { PageObjects::Pages::CSVExportPM.new }
  let(:time_format) { "%Y-%m-%d %H:%M:%S UTC" }

  before do
    Jobs.run_immediately!
    sign_in(admin)
  end

  context "with user list" do
    fab!(:group1) { Fabricate(:group) }
    fab!(:group2) { Fabricate(:group) }
    fab!(:user) do
      Fabricate(
        :user,
        title: "dr",
        last_seen_at: Time.now,
        last_posted_at: Time.now,
        last_emailed_at: Time.now,
        approved: true,
        suspended_at: Time.now,
        suspended_till: Time.now,
        silenced_till: Time.now,
        admin: true,
        moderator: true,
        staged: true,
        group_ids: [group1.id, group2.id],
      )
    end
    let(:second_email) { "second_email@discourse.org" }
    let(:third_email) { "third_email@discourse.org" }

    before do
      user.user_emails.create!(email: second_email)
      user.user_emails.create!(email: third_email)

      user.user_stat.topics_entered = 111
      user.user_stat.posts_read_count = 112
      user.user_stat.time_read = 113
      user.user_stat.topic_count = 114
      user.user_stat.post_count = 115
      user.user_stat.likes_given = 116
      user.user_stat.likes_received = 117
      user.user_stat.save!

      user.user_profile.location = "Tbilisi"
      user.user_profile.website = "https://www.discourse.org"
      user.user_profile.views = 5
      user.user_profile.save!
    end

    xit "exports data" do
      visit "admin/users/list/active"
      click_button "Export"

      visit "/u/#{admin.username}/messages"
      click_link "[User List] Data export complete"
      expect(csv_export_pm_page).to have_download_link
      exported_data = csv_export_pm_page.download_and_extract

      expect(exported_data.length).to be(5)
      expect(exported_data.first).to eq(
        %w[
          id
          name
          username
          email
          title
          created_at
          last_seen_at
          last_posted_at
          last_emailed_at
          trust_level
          approved
          suspended_at
          suspended_till
          silenced_till
          active
          admin
          moderator
          ip_address
          staged
          secondary_emails
          topics_entered
          posts_read_count
          time_read
          topic_count
          post_count
          likes_given
          likes_received
          location
          website
          views
          group_names
        ],
      )
      expect(exported_data.last).to eq(
        [
          user.id.to_s,
          user.name,
          user.username,
          user.email,
          user.title,
          user.created_at.strftime(time_format),
          user.last_seen_at.strftime(time_format),
          user.last_posted_at.strftime(time_format),
          user.last_emailed_at.strftime(time_format),
          user.trust_level.to_s,
          user.approved.to_s,
          user.suspended_at.strftime(time_format),
          user.suspended_till.strftime(time_format),
          user.silenced_till.strftime(time_format),
          user.active.to_s,
          user.admin.to_s,
          user.moderator.to_s,
          user.ip_address.to_s,
          user.staged.to_s,
          "#{second_email};#{third_email}",
          user.user_stat.topics_entered.to_s,
          user.user_stat.posts_read_count.to_s,
          user.user_stat.time_read.to_s,
          user.user_stat.topic_count.to_s,
          user.user_stat.post_count.to_s,
          user.user_stat.likes_given.to_s,
          user.user_stat.likes_received.to_s,
          user.user_profile.location,
          user.user_profile.website,
          user.user_profile.views.to_s,
          "#{group1.name};#{group2.name}",
        ],
      )
    ensure
      csv_export_pm_page.clear_downloads
    end
  end

  context "with stuff actions log" do
    fab!(:user_history) do
      Fabricate(
        :user_history,
        acting_user: admin,
        action: UserHistory.actions[:change_site_setting],
        subject: "default_trust_level",
        details: "details",
        context: "context",
      )
    end

    xit "exports data" do
      visit "admin/logs/staff_action_logs"
      click_button "Export"

      visit "/u/#{admin.username}/messages"
      click_link "[Staff Action] Data export complete"
      expect(csv_export_pm_page).to have_download_link
      exported_data = csv_export_pm_page.download_and_extract

      expect(exported_data.first).to eq(%w[staff_user action subject created_at details context])

      expect(exported_data.last).to eq(
        [
          user_history.acting_user.username,
          "change_site_setting",
          user_history.subject,
          user_history.created_at.strftime(time_format),
          user_history.details,
          user_history.context,
        ],
      )
    ensure
      csv_export_pm_page.clear_downloads
    end
  end

  context "with reports" do
    before do
      freeze_time # otherwise the test can fail when ran in midnight
      Fabricate(:bookmark)
    end

    xit "exports the Bookmarks report" do
      visit "admin/reports/bookmarks"
      click_button "Export"

      visit "/u/#{admin.username}/messages"
      click_link "[Bookmarks] Data export complete"
      expect(csv_export_pm_page).to have_download_link
      exported_data = csv_export_pm_page.download_and_extract

      expect(exported_data.length).to be(2)
      expect(exported_data.first).to eq(%w[Day Count])
      expect(exported_data.second).to eq([Time.now.strftime("%Y-%m-%d"), "1"])
    ensure
      csv_export_pm_page.clear_downloads
    end
  end

  context "with screened emails" do
    fab!(:screened_email_1) do
      Fabricate(
        :screened_email,
        action_type: ScreenedEmail.actions[:do_nothing],
        match_count: 1,
        last_match_at: Time.now + 1.day,
        created_at: Time.now + 1.day,
        ip_address: "11.11.11.11",
      )
    end
    fab!(:screened_email_2) do
      Fabricate(
        :screened_email,
        action_type: ScreenedEmail.actions[:do_nothing],
        match_count: 2,
        last_match_at: Time.now + 2.days,
        created_at: Time.now + 2.days,
        ip_address: "22.22.22.22",
      )
    end

    xit "exports data" do
      visit "admin/logs/screened_emails"
      click_button "Export"

      visit "/u/#{admin.username}/messages"
      click_link "[Screened Email] Data export complete"
      expect(csv_export_pm_page).to have_download_link
      exported_data = csv_export_pm_page.download_and_extract

      expect(exported_data.length).to be(3)
      expect(exported_data.first).to eq(
        %w[email action match_count last_match_at created_at ip_address],
      )
      assert_export(exported_data.second, screened_email_2)
      assert_export(exported_data.third, screened_email_1)
    ensure
      csv_export_pm_page.clear_downloads
    end

    def assert_export(exported_email, email)
      expect(exported_email).to eq(
        [
          email.email,
          "do_nothing",
          email.match_count.to_s,
          email.last_match_at.strftime(time_format),
          email.created_at.strftime(time_format),
          email.ip_address.to_s,
        ],
      )
    end
  end

  context "with screened ips" do
    fab!(:screened_ip_1) do
      Fabricate(
        :screened_ip_address,
        action_type: ScreenedIpAddress.actions[:do_nothing],
        match_count: 1,
        ip_address: "11.11.11.11",
        last_match_at: Time.now + 1.day,
        created_at: Time.now + 1.day,
      )
    end
    fab!(:screened_ip_2) do
      Fabricate(
        :screened_ip_address,
        action_type: ScreenedIpAddress.actions[:do_nothing],
        match_count: 2,
        ip_address: "22.22.22.22",
        last_match_at: Time.now + 2.days,
        created_at: Time.now + 2.days,
      )
    end

    it "exports data" do
      visit "admin/logs/screened_ip_addresses"
      click_button "Export"

      visit "/u/#{admin.username}/messages"
      click_link "[Screened Ip] Data export complete"
      expect(csv_export_pm_page).to have_download_link
      exported_data = csv_export_pm_page.download_and_extract

      expect(exported_data.first).to eq(%w[ip_address action match_count last_match_at created_at])
      assert_exported_row(exported_data.second, screened_ip_2)
      assert_exported_row(exported_data.third, screened_ip_1)
    ensure
      csv_export_pm_page.clear_downloads
    end

    def assert_exported_row(exported_ip, ip)
      expect(exported_ip).to eq(
        [
          ip.ip_address.to_s,
          "do_nothing",
          ip.match_count.to_s,
          ip.last_match_at.strftime(time_format),
          ip.created_at.strftime(time_format),
        ],
      )
    end
  end

  context "with screened urls" do
    fab!(:screened_url) do
      Fabricate(
        :screened_url,
        action_type: ScreenedUrl.actions[:do_nothing],
        match_count: 5,
        domain: "https://discourse.org",
        last_match_at: Time.now,
        created_at: Time.now,
      )
    end

    xit "exports data" do
      visit "admin/logs/screened_urls"
      click_button "Export"

      visit "/u/#{admin.username}/messages"
      click_link "[Screened Url] Data export complete"
      expect(csv_export_pm_page).to have_download_link
      exported_data = csv_export_pm_page.download_and_extract

      expect(exported_data.length).to be(2)
      expect(exported_data.first).to eq(%w[domain action match_count last_match_at created_at])
      expect(exported_data.second).to eq(
        [
          screened_url.domain,
          "do nothing",
          screened_url.match_count.to_s,
          screened_url.last_match_at.strftime(time_format),
          screened_url.created_at.strftime(time_format),
        ],
      )
    ensure
      csv_export_pm_page.clear_downloads
    end
  end
end
