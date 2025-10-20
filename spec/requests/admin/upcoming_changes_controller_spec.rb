# frozen_string_literal: true

RSpec.describe Admin::Config::UpcomingChangesController do
  fab!(:admin)

  before { sign_in(admin) }

  describe "#index" do
    it "gets all the upcoming changes for the admin" do
      get "/admin/config/upcoming-changes.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to be_an(Array)
    end
  end
end
