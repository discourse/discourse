# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::ChatController do
  describe "#export_messages" do
    fab!(:user) { Fabricate(:user) }
    fab!(:moderator) { Fabricate(:moderator) }
    fab!(:admin) { Fabricate(:admin) }

    it "enqueues the export job and logs into staff actions" do
      sign_in(admin)

      post "/chat/admin/export/messages"

      expect(response.status).to eq(204)

      expect(Jobs::ExportCsvFile.jobs.size).to eq(1)
      job_data = Jobs::ExportCsvFile.jobs.first["args"].first
      expect(job_data["entity"]).to eq("chat_message")
      expect(job_data["user_id"]).to eq(admin.id)

      staff_log_entry = UserHistory.last
      expect(staff_log_entry.acting_user_id).to eq(admin.id)
      expect(staff_log_entry.subject).to eq("chat_message")
    end

    it "regular users don't have access" do
      sign_in(user)
      post "/chat/admin/export/messages"
      expect(response.status).to eq(403)
    end

    it "moderators don't have access" do
      sign_in(moderator)
      post "/chat/admin/export/messages"
      expect(response.status).to eq(403)
    end
  end
end
