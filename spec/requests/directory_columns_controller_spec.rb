# frozen_string_literal: true

require 'rails_helper'

describe DirectoryColumnsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  describe "#index" do
    it "returns all active directory columns" do
      likes_given = DirectoryColumn.find_by(name: "likes_given")
      likes_given.update(enabled: false)

      get "/directory-columns.json"

      expect(response.parsed_body["directory_columns"].map { |dc| dc["name"] }).not_to include("likes_given")
    end
  end

  describe "#edit-index" do
    fab!(:public_user_field) { Fabricate(:user_field, show_on_profile: true) }
    fab!(:private_user_field) { Fabricate(:user_field, show_on_profile: false, show_on_user_card: false) }

    it "creates directory column records for public user fields" do
      sign_in(admin)

      expect {
        get "/edit-directory-columns.json"
      }.to change { DirectoryColumn.count }.by(1)
    end

    it "returns a 403 when not logged in as staff member" do
      sign_in(user)
      get "/edit-directory-columns.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#update" do
    let(:first_directory_column_id) { DirectoryColumn.first.id }
    let(:second_directory_column_id) { DirectoryColumn.second.id }
    let(:params) {
      {
        directory_columns: {
          "0": {
            id: first_directory_column_id,
            enabled: false,
            position: 1
          },
          "1": {
            id: second_directory_column_id,
            enabled: true,
            position: 1
          }
        }
      }
    }

    it "updates exising directory columns" do
      sign_in(admin)

      expect {
        put "/edit-directory-columns.json", params: params
      }.to change { DirectoryColumn.find(first_directory_column_id).enabled }.from(true).to(false)
    end

    it "does not let all columns be disabled" do
      sign_in(admin)
      bad_params = params
      bad_params[:directory_columns][:"1"][:enabled] = false

      put "/edit-directory-columns.json", params: bad_params

      expect(response.status).to eq(400)
    end

    it "returns a 404 when not logged in as a staff member" do
      sign_in(user)
      put "/edit-directory-columns.json", params: params

      expect(response.status).to eq(404)
    end
  end
end
