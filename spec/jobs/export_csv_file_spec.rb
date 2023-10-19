# frozen_string_literal: true

RSpec.describe Jobs::ExportCsvFile do
  describe "#execute" do
    let(:other_user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let(:action_log) { StaffActionLogger.new(admin).log_revoke_moderation(other_user) }

    it "raises an error when the entity is missing" do
      expect { Jobs::ExportCsvFile.new.execute(user_id: admin.id) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "works" do
      action_log

      begin
        expect do
          Jobs::ExportCsvFile.new.execute(user_id: admin.id, entity: "staff_action")
        end.to change { Upload.count }.by(1)

        system_message = admin.topics_allowed.last

        expect(system_message.title).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.subject_template",
            export_title: "Staff Action",
          ),
        )

        upload = system_message.first_post.uploads.first

        expect(system_message.first_post.raw).to eq(
          I18n.t(
            "system_messages.csv_export_succeeded.text_body_template",
            download_link:
              "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.filesize} Bytes)",
          ).chomp,
        )

        expect(system_message.id).to eq(UserExport.last.topic_id)
        expect(system_message.closed).to eq(true)

        files = []
        Zip::File.open(Discourse.store.path_for(upload)) do |zip_file|
          zip_file.each { |entry| files << entry.name }
        end

        expect(files.size).to eq(1)
      ensure
        admin.uploads.each(&:destroy!)
      end
    end
  end

  describe ".report_export" do
    let(:user) { Fabricate(:admin) }

    let(:exporter) do
      exporter = Jobs::ExportCsvFile.new
      exporter.entity = "report"
      exporter.extra =
        HashWithIndifferentAccess.new(start_date: "2010-01-01", end_date: "2011-01-01")
      exporter.current_user = User.find_by(id: user.id)
      exporter
    end

    it "does not throw an error when the dates are invalid" do
      Jobs::ExportCsvFile.new.execute(
        entity: "report",
        user_id: user.id,
        args: {
          start_date: "asdfasdf",
          end_date: "not-a-date",
          name: "dau_by_mau",
        },
      )
    end

    it "works with single-column reports" do
      user.user_visits.create!(visited_at: "2010-01-01", posts_read: 42)
      Fabricate(:user).user_visits.create!(visited_at: "2010-01-03", posts_read: 420)
      exporter.extra["name"] = "dau_by_mau"

      report = export_report

      expect(report.first).to contain_exactly("Day", "Percent")
      expect(report.second).to contain_exactly("2010-01-01", "100.0")
      expect(report.third).to contain_exactly("2010-01-03", "50.0")
    end

    it "works with filters" do
      user.user_visits.create!(visited_at: "2010-01-01", posts_read: 42)

      group = Fabricate(:group)
      user1 = Fabricate(:user)
      Fabricate(:group_user, group: group, user: user1)
      user1.user_visits.create!(visited_at: "2010-01-03", posts_read: 420)

      exporter.extra["name"] = "visits"
      exporter.extra["group"] = group.id

      report = export_report

      expect(report.length).to eq(2)
      expect(report.first).to contain_exactly("Day", "Count")
      expect(report.second).to contain_exactly("2010-01-03", "1")
    end

    it "works with single-column reports with default label" do
      user.user_visits.create!(visited_at: "2010-01-01")
      Fabricate(:user).user_visits.create!(visited_at: "2010-01-03")
      exporter.extra["name"] = "visits"

      report = export_report

      expect(report.first).to contain_exactly("Day", "Count")
      expect(report.second).to contain_exactly("2010-01-01", "1")
      expect(report.third).to contain_exactly("2010-01-03", "1")
    end

    it "works with multi-columns reports" do
      DiscourseIpInfo.stubs(:get).with("1.1.1.1").returns(location: "Earth")
      user.user_auth_token_logs.create!(
        action: "login",
        client_ip: "1.1.1.1",
        created_at: "2010-01-01",
      )
      exporter.extra["name"] = "staff_logins"

      report = export_report

      expect(report.first).to contain_exactly("User", "Location", "Login at")
      expect(report.second).to contain_exactly(user.username, "Earth", "2010-01-01 00:00:00 UTC")
    end

    it "works with topic reports" do
      freeze_time DateTime.parse("2010-01-01 6:00")

      exporter.extra["name"] = "top_referred_topics"
      post1 = Fabricate(:post)
      Fabricate(:post)
      IncomingLink.add(
        host: "a.com",
        referer: "http://twitter.com",
        post_id: post1.id,
        ip_address: "1.1.1.1",
      )

      report = export_report

      expect(report.first).to contain_exactly("Topic", "Clicks")
      expect(report.second).to contain_exactly(post1.topic.id.to_s, "1")
    end

    it "works with stacked_chart reports" do
      ApplicationRequest.create!(date: "2010-01-01", req_type: "page_view_logged_in", count: 1)
      ApplicationRequest.create!(date: "2010-01-02", req_type: "page_view_logged_in", count: 2)
      ApplicationRequest.create!(date: "2010-01-03", req_type: "page_view_logged_in", count: 3)

      ApplicationRequest.create!(date: "2010-01-01", req_type: "page_view_anon", count: 4)
      ApplicationRequest.create!(date: "2010-01-02", req_type: "page_view_anon", count: 5)
      ApplicationRequest.create!(date: "2010-01-03", req_type: "page_view_anon", count: 6)

      ApplicationRequest.create!(date: "2010-01-01", req_type: "page_view_crawler", count: 7)
      ApplicationRequest.create!(date: "2010-01-02", req_type: "page_view_crawler", count: 8)
      ApplicationRequest.create!(date: "2010-01-03", req_type: "page_view_crawler", count: 9)

      exporter.extra["name"] = "consolidated_page_views"

      report = export_report

      expect(report[0]).to contain_exactly("Day", "Logged in users", "Anonymous users", "Crawlers")
      expect(report[1]).to contain_exactly("2010-01-01", "1", "4", "7")
      expect(report[2]).to contain_exactly("2010-01-02", "2", "5", "8")
      expect(report[3]).to contain_exactly("2010-01-03", "3", "6", "9")
    end

    it "works with posts reports and filters" do
      category = Fabricate(:category)
      subcategory = Fabricate(:category, parent_category: category)

      Fabricate(
        :post,
        topic: Fabricate(:topic, category: category),
        created_at: "2010-01-01 12:00:00 UTC",
      )
      Fabricate(
        :post,
        topic: Fabricate(:topic, category: subcategory),
        created_at: "2010-01-01 12:00:00 UTC",
      )

      exporter.extra["name"] = "posts"

      exporter.extra["category"] = category.id

      report = export_report

      expect(report[0]).to contain_exactly("Count", "Day")
      expect(report[1]).to contain_exactly("1", "2010-01-01")

      exporter.extra["include_subcategories"] = true

      report = export_report

      expect(report[0]).to contain_exactly("Count", "Day")
      expect(report[1]).to contain_exactly("2", "2010-01-01")
    end

    def export_report
      report = []
      exporter.report_export { |entry| report << entry }
      report
    end
  end

  let(:user_list_header) do
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
      blocked
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
      external_id
      external_email
      external_username
      external_name
      external_avatar_url
    ]
  end

  let(:user_list_export) do
    exported_data = []
    Jobs::ExportCsvFile.new.user_list_export { |entry| exported_data << entry }
    exported_data
  end

  def to_hash(row)
    Hash[*user_list_header.zip(row).flatten]
  end

  it "exports secondary emails" do
    user = Fabricate(:user)
    Fabricate(:secondary_email, user: user, primary: false)
    secondary_emails = user.secondary_emails

    user = to_hash(user_list_export.find { |u| u[0].to_i == user.id })

    expect(user["secondary_emails"].split(";")).to match_array(secondary_emails)
  end

  it "exports sso data" do
    SiteSetting.discourse_connect_url = "https://www.example.com/sso"
    SiteSetting.enable_discourse_connect = true
    user = Fabricate(:user)
    user.user_profile.update_column(:location, "La,La Land")
    user.create_single_sign_on_record(
      external_id: "123",
      last_payload: "xxx",
      external_email: "test@test.com",
    )

    user = to_hash(user_list_export.find { |u| u[0].to_i == user.id })

    expect(user["location"]).to eq('"La,La Land"')
    expect(user["external_id"]).to eq("123")
    expect(user["external_email"]).to eq("test@test.com")
  end
end
