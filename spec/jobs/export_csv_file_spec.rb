# frozen_string_literal: true

require 'rails_helper'

describe Jobs::ExportCsvFile do

  context '#execute' do
    fab!(:user) { Fabricate(:user, username: "john_doe") }

    it 'raises an error when the entity is missing' do
      expect { Jobs::ExportCsvFile.new.execute(user_id: user.id) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'works' do
      begin
        expect do
          Jobs::ExportCsvFile.new.execute(
            user_id: user.id,
            entity: "user_archive"
          )
        end.to change { Upload.count }.by(1)

        system_message = user.topics_allowed.last

        expect(system_message.title).to eq(I18n.t(
          "system_messages.csv_export_succeeded.subject_template",
          export_title: "User Archive"
        ))

        upload = system_message.first_post.uploads.first

        expect(system_message.first_post.raw).to eq(I18n.t(
          "system_messages.csv_export_succeeded.text_body_template",
          download_link: "[#{upload.original_filename}|attachment](#{upload.short_url}) (#{upload.filesize} Bytes)"
        ).chomp)

        expect(system_message.id).to eq(UserExport.last.topic_id)
        expect(system_message.closed).to eq(true)
      ensure
        user.uploads.each(&:destroy!)
      end
    end
  end

  context '#user_archive_export' do
    let(:user) { Fabricate(:user) }

    let(:category) { Fabricate(:category_with_definition) }
    let(:subcategory) { Fabricate(:category_with_definition, parent_category_id: category.id) }
    let(:subsubcategory) { Fabricate(:category_with_definition, parent_category_id: subcategory.id) }

    it 'works with sub-sub-categories' do
      SiteSetting.max_category_nesting = 3
      topic = Fabricate(:topic, category: subsubcategory)
      post = Fabricate(:post, topic: topic, user: user)

      exporter = Jobs::ExportCsvFile.new
      exporter.instance_variable_set(:@current_user, User.find_by(id: user.id))

      rows = []
      exporter.user_archive_export { |row| rows << row }

      expect(rows.length).to eq(1)

      first_row = Jobs::ExportCsvFile::HEADER_ATTRS_FOR['user_archive'].zip(rows[0]).to_h

      expect(first_row["topic_title"]).to eq(topic.title)
      expect(first_row["categories"]).to eq("#{category.name}|#{subcategory.name}|#{subsubcategory.name}")
      expect(first_row["is_pm"]).to eq(I18n.t("csv_export.boolean_no"))
      expect(first_row["post"]).to eq(post.raw)
      expect(first_row["like_count"]).to eq(0)
      expect(first_row["reply_count"]).to eq(0)
    end
  end

  context '.report_export' do

    let(:user) { Fabricate(:admin) }

    let(:exporter) do
      exporter = Jobs::ExportCsvFile.new
      exporter.instance_variable_set(:@entity, 'report')
      exporter.instance_variable_set(:@extra, HashWithIndifferentAccess.new(start_date: '2010-01-01', end_date: '2011-01-01'))
      exporter.instance_variable_set(:@current_user, User.find_by(id: user.id))
      exporter
    end

    it 'works with single-column reports' do
      user.user_visits.create!(visited_at: '2010-01-01', posts_read: 42)
      Fabricate(:user).user_visits.create!(visited_at: '2010-01-03', posts_read: 420)

      exporter.instance_variable_get(:@extra)['name'] = 'dau_by_mau'
      report = exporter.report_export.to_a

      expect(report.first).to contain_exactly("Day", "Percent")
      expect(report.second).to contain_exactly("2010-01-01", "100.0")
      expect(report.third).to contain_exactly("2010-01-03", "50.0")
    end

    it 'works with single-column reports with default label' do
      user.user_visits.create!(visited_at: '2010-01-01')
      Fabricate(:user).user_visits.create!(visited_at: '2010-01-03')

      exporter.instance_variable_get(:@extra)['name'] = 'visits'
      report = exporter.report_export.to_a

      expect(report.first).to contain_exactly("Day", "Count")
      expect(report.second).to contain_exactly("2010-01-01", "1")
      expect(report.third).to contain_exactly("2010-01-03", "1")
    end

    it 'works with multi-columns reports' do
      DiscourseIpInfo.stubs(:get).with("1.1.1.1").returns(location: "Earth")
      user.user_auth_token_logs.create!(action: "login", client_ip: "1.1.1.1", created_at: '2010-01-01')

      exporter.instance_variable_get(:@extra)['name'] = 'staff_logins'
      report = exporter.report_export.to_a

      expect(report.first).to contain_exactly("User", "Location", "Login at")
      expect(report.second).to contain_exactly(user.username, "Earth", "2010-01-01 00:00:00 UTC")
    end

    it 'works with stacked_chart reports' do
      ApplicationRequest.create!(date: '2010-01-01', req_type: 'page_view_logged_in', count: 1)
      ApplicationRequest.create!(date: '2010-01-02', req_type: 'page_view_logged_in', count: 2)
      ApplicationRequest.create!(date: '2010-01-03', req_type: 'page_view_logged_in', count: 3)

      ApplicationRequest.create!(date: '2010-01-01', req_type: 'page_view_anon', count: 4)
      ApplicationRequest.create!(date: '2010-01-02', req_type: 'page_view_anon', count: 5)
      ApplicationRequest.create!(date: '2010-01-03', req_type: 'page_view_anon', count: 6)

      ApplicationRequest.create!(date: '2010-01-01', req_type: 'page_view_crawler', count: 7)
      ApplicationRequest.create!(date: '2010-01-02', req_type: 'page_view_crawler', count: 8)
      ApplicationRequest.create!(date: '2010-01-03', req_type: 'page_view_crawler', count: 9)

      exporter.instance_variable_get(:@extra)['name'] = 'consolidated_page_views'
      report = exporter.report_export.to_a

      expect(report[0]).to contain_exactly("Day", "Logged in users", "Anonymous users", "Crawlers")
      expect(report[1]).to contain_exactly("2010-01-01", "1", "4", "7")
      expect(report[2]).to contain_exactly("2010-01-02", "2", "5", "8")
      expect(report[3]).to contain_exactly("2010-01-03", "3", "6", "9")
    end

  end

  let(:user_list_header) {
    %w{
      id name username email title created_at last_seen_at last_posted_at
      last_emailed_at trust_level approved suspended_at suspended_till blocked
      active admin moderator ip_address staged secondary_emails topics_entered
      posts_read_count time_read topic_count post_count likes_given
      likes_received location website views external_id external_email
      external_username external_name external_avatar_url
    }
  }

  let(:user_list_export) { Jobs::ExportCsvFile.new.user_list_export }

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

  it 'exports sso data' do
    SiteSetting.sso_url = "https://www.example.com/sso"
    SiteSetting.enable_sso = true
    user = Fabricate(:user)
    user.user_profile.update_column(:location, "La,La Land")
    user.create_single_sign_on_record(external_id: "123", last_payload: "xxx", external_email: 'test@test.com')

    user = to_hash(user_list_export.find { |u| u[0].to_i == user.id })

    expect(user["location"]).to eq('"La,La Land"')
    expect(user["external_id"]).to eq("123")
    expect(user["external_email"]).to eq("test@test.com")
  end
end
