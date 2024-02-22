# frozen_string_literal: true

require "rspec"

RSpec.describe EditDirectoryColumnsController do
  fab!(:admin)
  fab!(:user)

  describe "#update" do
    let(:first_directory_column_id) { DirectoryColumn.first.id }
    let(:second_directory_column_id) { DirectoryColumn.second.id }
    let!(:payload) do
      {
        directory_columns: {
          "0": {
            id: first_directory_column_id,
            enabled: "false",
            position: "2",
          },
          "1": {
            id: second_directory_column_id,
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
            expect { put edit_directory_columns_path(params: payload) }.to change {
              DirectoryColumn.find(first_directory_column_id).enabled
            }.from(true).to(false)

            staff_log = UserHistory.last

            expect(staff_log.custom_type).to eq("update_directory_columns")
          end

          it "does not let all columns be disabled" do
            sign_in(admin)
            bad_params = payload
            bad_params[:directory_columns][:"1"][:enabled] = "false"

            put edit_directory_columns_path(params: bad_params)

            expect(response.status).to eq(400)
          end
        end
      end
    end

    describe "when user is not an admin or moderator" do
      before { sign_in(user) }
      describe "user saves a new configuration" do
        it "does not allow saving" do
          put edit_directory_columns_path(params: payload)

          expect(response.status).to eq(403)
        end
      end
    end
  end

  describe "#index" do
    fab!(:public_user_field) { Fabricate(:user_field, show_on_profile: true) }
    fab!(:private_user_field) do
      Fabricate(:user_field, show_on_profile: false, show_on_user_card: false)
    end

    it "creates directory column records for public user fields" do
      sign_in(admin)

      expect { get "/edit-directory-columns.json" }.to change { DirectoryColumn.count }.by(1)
    end

    it "returns a 403 when not logged in as staff member" do
      sign_in(user)
      get "/edit-directory-columns.json"

      expect(response.status).to eq(403)
    end
  end
end
