require "rails_helper"

describe ExportCsvController do
  let(:export_filename) { "user-archive-codinghorror-150115-234817-999.csv.gz" }

  context "while logged in as normal user" do
    let(:user) { Fabricate(:user) }
    before { sign_in(user) }

    describe ".export_entity" do
      it "enqueues export job" do
        post "/export_csv/export_entity.json", params: { entity: "user_archive" }
        expect(response.status).to eq(200)
        expect(Jobs::ExportCsvFile.jobs.size).to eq(1)

        job_data = Jobs::ExportCsvFile.jobs.first["args"].first
        expect(job_data["entity"]).to eq("user_archive")
        expect(job_data["user_id"]).to eq(user.id)
      end

      it "should not enqueue export job if rate limit is reached" do
        UserExport.create(file_name: "user-archive-codinghorror-150116-003249", user_id: user.id)
        post "/export_csv/export_entity.json", params: { entity: "user_archive" }
        expect(response).to be_forbidden
        expect(Jobs::ExportCsvFile.jobs.size).to eq(0)
      end

      it "returns 404 when normal user tries to export admin entity" do
        post "/export_csv/export_entity.json", params: { entity: "staff_action" }
        expect(response).to be_forbidden
        expect(Jobs::ExportCsvFile.jobs.size).to eq(0)
      end
    end
  end

  context "while logged in as an admin" do
    let(:admin) { Fabricate(:admin) }
    before { sign_in(admin) }

    describe ".export_entity" do
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
    end
  end
end
