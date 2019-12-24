# frozen_string_literal: true

require "rails_helper"

describe ExportCsvController do
  context "while logged in as normal user" do
    fab!(:user) { Fabricate(:user) }
    before { sign_in(user) }

    describe "#export_entity" do
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
        expect(response.status).to eq(422)
        expect(Jobs::ExportCsvFile.jobs.size).to eq(0)
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
    fab!(:admin) { Fabricate(:admin) }
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
    end
  end

  context 'while logged in as a moderator' do
    fab!(:moderator) { Fabricate(:moderator) }

    before { sign_in(moderator) }

    describe '#export_entity' do
      it 'does not allow moderators to export user_list' do
        post '/export_csv/export_entity.json', params: { entity: 'user_list' }
        expect(response.status).to eq(422)
      end

      it 'allows moderator to export other entities' do
        post "/export_csv/export_entity.json", params: { entity: 'staff_action' }
        expect(response.status).to eq(200)
        expect(Jobs::ExportCsvFile.jobs.size).to eq(1)

        job_data = Jobs::ExportCsvFile.jobs.first['args'].first
        expect(job_data['entity']).to eq('staff_action')
        expect(job_data['user_id']).to eq(moderator.id)
      end
    end
  end
end
