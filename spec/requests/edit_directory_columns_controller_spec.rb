# frozen_string_literal: true

require "rspec"

RSpec.describe EditDirectoryColumnsController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:normal_user) { Fabricate(:user) }
  let!(:payload) do
    {
      directory_columns: {
        "0": {
          id: "1",
          enabled: "true",
          position: "2",
        },
        "1": {
          id: "2",
          enabled: "true",
          position: "1",
        },
      },
      format: "json",
    }
  end

  describe "#update" do
    describe "when user is an admin or moderator" do
      before { sign_in(admin) }
      describe "user saves a new configuration" do
        it "logs the new information using StaffActionLogger" do
          put edit_directory_columns_path(params: payload)
          staff_log = UserHistory.last

          expect(staff_log.custom_type).to eq("update_directory_columns")
        end
      end
    end

    describe "when user is not an admin or moderator" do
      before { sign_in(normal_user) }
      describe "user saves a new configuration" do
        it "does not allow saving" do
          put edit_directory_columns_path(params: payload)

          expect(response.status).to eq(403)
        end
      end
    end
  end

  describe "#index" do
    describe "when user is not an admin or moderator" do
      before { sign_in(normal_user) }
      describe "user checks current configuration" do
        it "does not allow the configuration to load" do
          get edit_directory_columns_path << ".json"

          expect(response.status).to eq(403)
        end
      end
    end
  end
end
