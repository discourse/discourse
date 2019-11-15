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
