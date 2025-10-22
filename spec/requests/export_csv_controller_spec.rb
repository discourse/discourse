# frozen_string_literal: true

RSpec.describe ExportCsvController do
  context "while logged in as normal user" do
    fab!(:user)
    fab!(:user2, :user)
    before { sign_in(user) }

    describe "#export_entity" do
      it "enqueues user archive job" do
        post "/export_csv/export_entity.json", params: { entity: "user_archive" }
        expect(response.status).to eq(200)
        expect(Jobs::ExportUserArchive.jobs.size).to eq(1)

        job_data = Jobs::ExportUserArchive.jobs.first["args"].first
        expect(job_data["user_id"]).to eq(user.id)
      end

      it "should not enqueue export job if rate limit is reached" do
        UserExport.create(file_name: "user-archive-codinghorror-150116-003249", user_id: user.id)
        post "/export_csv/export_entity.json", params: { entity: "user_archive" }
        expect(response.status).to eq(422)
        expect(Jobs::ExportUserArchive.jobs.size).to eq(0)
      end

      it "returns 404 when normal user tries to export admin entity" do
        post "/export_csv/export_entity.json", params: { entity: "staff_action" }
        expect(response.status).to eq(422)
        expect(Jobs::ExportCsvFile.jobs.size).to eq(0)
      end

      it "does not allow a normal user to export another user's archive" do
        post "/export_csv/export_entity.json",
             params: {
               entity: "user_archive",
               args: {
                 export_user_id: user2.id,
               },
             }
        expect(response.status).to eq(422)
        expect(Jobs::ExportUserArchive.jobs.size).to eq(0)
      end

      it "correctly logs the entity export" do
        post "/export_csv/export_entity.json", params: { entity: "user_archive" }

        log_entry = UserHistory.last
        expect(log_entry.action).to eq(UserHistory.actions[:entity_export])
        expect(log_entry.acting_user_id).to eq(user.id)
        expect(log_entry.subject).to eq("user_archive")
      end
    end

    describe "#latest_user_archive" do
      it "returns the latest user archive" do
        export = generate_exports(user)

        get "/export_csv/latest_user_archive/#{user.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["user_export"]["id"]).to eq(export.id)
      end

      it "returns nothing when the user has no archives" do
        get "/export_csv/latest_user_archive/#{user.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq(nil)
      end

      it "does not allow a normal user to view another user's archive" do
        generate_exports(user2)
        get "/export_csv/latest_user_archive/#{user2.id}.json"
        expect(response.status).to eq(403)
      end
    end
  end

  context "while logged in as an admin" do
    fab!(:user)
    fab!(:admin)
    before { sign_in(admin) }

    describe "#export_entity" do
      it "enqueues export job" do
        post "/export_csv/export_entity.json", params: { entity: "staff_action" }
        expect(response.status).to eq(200)
        expect(Jobs::ExportCsvFile.jobs.size).to eq(1)

        job_data = Jobs::ExportCsvFile.jobs.first["args"].first
        expect(job_data["entity"]).to eq("staff_action")
        expect(job_data["user_id"]).to eq(admin.id)
      end

      it "should not rate limit export for staff" do
        UserExport.create(file_name: "screened-email-150116-010145", user_id: admin.id)
        post "/export_csv/export_entity.json", params: { entity: "staff_action" }
        expect(response.status).to eq(200)
        expect(Jobs::ExportCsvFile.jobs.size).to eq(1)

        job_data = Jobs::ExportCsvFile.jobs.first["args"].first
        expect(job_data["entity"]).to eq("staff_action")
        expect(job_data["user_id"]).to eq(admin.id)
      end

      it "allows user archives for other users" do
        post "/export_csv/export_entity.json",
             params: {
               entity: "user_archive",
               args: {
                 export_user_id: user.id,
               },
             }
        expect(response.status).to eq(200)
        expect(Jobs::ExportUserArchive.jobs.size).to eq(1)

        job_data = Jobs::ExportUserArchive.jobs.first["args"].first
        expect(job_data["user_id"]).to eq(user.id)
      end

      it "correctly logs the entity export" do
        post "/export_csv/export_entity.json", params: { entity: "user_list" }

        log_entry = UserHistory.last
        expect(log_entry.action).to eq(UserHistory.actions[:entity_export])
        expect(log_entry.acting_user_id).to eq(admin.id)
        expect(log_entry.subject).to eq("user_list")
      end

      it "fails requests where the entity is too long" do
        post "/export_csv/export_entity.json", params: { entity: "x" * 200 }
        expect(response.status).to eq(400)
      end

      it "fails requests where the name arg is too long" do
        post "/export_csv/export_entity.json", params: { entity: "foo", args: { name: "x" * 200 } }
        expect(response.status).to eq(400)
      end
    end

    describe "#latest_user_archive" do
      it "allows an admin to view another user's archive" do
        export = generate_exports(user)
        get "/export_csv/latest_user_archive/#{user.id}.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["user_export"]["id"]).to eq(export.id)
      end
    end
  end

  context "while logged in as a moderator" do
    fab!(:user)
    fab!(:moderator)

    before { sign_in(moderator) }

    describe "#export_entity" do
      it "does not allow moderators to export user_list" do
        post "/export_csv/export_entity.json", params: { entity: "user_list" }
        expect(response.status).to eq(422)
      end

      it "does not allow moderators to export screened_email if they has no permission to view emails" do
        SiteSetting.moderators_view_emails = false
        post "/export_csv/export_entity.json", params: { entity: "screened_email" }
        expect(response.status).to eq(422)
      end

      it "allows moderator to export screened_email if they has permission to view emails" do
        SiteSetting.moderators_view_emails = true
        post "/export_csv/export_entity.json", params: { entity: "screened_email" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")

        job_data = Jobs::ExportCsvFile.jobs.first["args"].first
        expect(job_data["entity"]).to eq("screened_email")
        expect(job_data["user_id"]).to eq(moderator.id)
      end

      it "does not allow moderators to export another user's archive" do
        post "/export_csv/export_entity.json",
             params: {
               entity: "user_archive",
               args: {
                 export_user_id: user.id,
               },
             }
        expect(response.status).to eq(422)
        expect(Jobs::ExportUserArchive.jobs.size).to eq(0)
      end

      it "allows moderator to export other entities" do
        post "/export_csv/export_entity.json", params: { entity: "staff_action" }
        expect(response.status).to eq(200)
        expect(Jobs::ExportCsvFile.jobs.size).to eq(1)

        job_data = Jobs::ExportCsvFile.jobs.first["args"].first
        expect(job_data["entity"]).to eq("staff_action")
        expect(job_data["user_id"]).to eq(moderator.id)
      end
    end

    describe "#latest_user_archive" do
      it "does not allow a moderator to view another user's archive" do
        generate_exports(user)
        get "/export_csv/latest_user_archive/#{user.id}.json"
        expect(response.status).to eq(403)
      end
    end
  end

  def generate_exports(user)
    csv_file_1 = Fabricate(:upload, created_at: 1.day.ago)
    topic_1 = Fabricate(:topic, created_at: 1.day.ago)
    Fabricate(:post, topic: topic_1)
    UserExport.create!(
      file_name: "test",
      user: user,
      upload_id: csv_file_1.id,
      topic_id: topic_1.id,
      created_at: 1.day.ago,
    )

    csv_file_2 = Fabricate(:upload, created_at: 12.hours.ago)
    topic_2 = Fabricate(:topic, created_at: 12.hours.ago)
    UserExport.create!(
      file_name: "test2",
      user: user,
      upload_id: csv_file_2.id,
      topic_id: topic_2.id,
      created_at: 12.hours.ago,
    )
  end
end
