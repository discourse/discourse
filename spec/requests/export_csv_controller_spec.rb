# frozen_string_literal: true

RSpec.describe ExportCsvController do
  context "while logged in as normal user" do
    fab!(:user)
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

      it "correctly logs the entity export" do
        post "/export_csv/export_entity.json", params: { entity: "user_archive" }

        log_entry = UserHistory.last
        expect(log_entry.action).to eq(UserHistory.actions[:entity_export])
        expect(log_entry.acting_user_id).to eq(user.id)
        expect(log_entry.subject).to eq("user_archive")
      end
    end
  end

  context "while logged in as an admin" do
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
  end

  context "while logged in as a moderator" do
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

      it "allows moderator to export other entities" do
        post "/export_csv/export_entity.json", params: { entity: "staff_action" }
        expect(response.status).to eq(200)
        expect(Jobs::ExportCsvFile.jobs.size).to eq(1)

        job_data = Jobs::ExportCsvFile.jobs.first["args"].first
        expect(job_data["entity"]).to eq("staff_action")
        expect(job_data["user_id"]).to eq(moderator.id)
      end
    end
  end
end
