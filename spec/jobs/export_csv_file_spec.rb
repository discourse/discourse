require 'rails_helper'

describe Jobs::ExportCsvFile do

  context '.execute' do
    let(:user) { Fabricate(:user, username: "john_doe") }

    it 'raises an error when the entity is missing' do
      expect { Jobs::ExportCsvFile.new.execute(user_id: user.id) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'works' do
      begin
        Jobs::ExportCsvFile.new.execute(user_id: user.id, entity: "user_archive")

        expect(user.topics_allowed.last.title).to eq(I18n.t(
          "system_messages.csv_export_succeeded.subject_template",
          export_title: "User Archive"
        ))
        expect(user.topics_allowed.last.first_post.raw).to include("user-archive-john_doe-")
      ensure
        user.uploads.find_each { |upload| upload.destroy! }
      end
    end
  end

  let(:user_list_header) {
    %w{
      id name username email title created_at last_seen_at last_posted_at
      last_emailed_at trust_level approved suspended_at suspended_till blocked
      active admin moderator ip_address staged topics_entered posts_read_count
      time_read topic_count post_count likes_given likes_received location
      website views external_id external_email external_username external_name
      external_avatar_url
    }
  }

  let(:user_list_export) { Jobs::ExportCsvFile.new.user_list_export }

  def to_hash(row)
    Hash[*user_list_header.zip(row).flatten]
  end

  it 'exports sso data' do
    SiteSetting.sso_url = "https://www.example.com/sso"
    SiteSetting.enable_sso = true
    user = Fabricate(:user)
    user.user_profile.update_column(:location, "La La Land")
    user.create_single_sign_on_record(external_id: "123", last_payload: "xxx", external_email: 'test@test.com')

    user = to_hash(user_list_export.find { |u| u[0].to_i == user.id })

    expect(user["location"]).to eq("La La Land")
    expect(user["external_id"]).to eq("123")
    expect(user["external_email"]).to eq("test@test.com")
  end
end
