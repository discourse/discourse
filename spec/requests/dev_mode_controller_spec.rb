# frozen_string_literal: true

RSpec.describe DevModeController do
  fab!(:developer) { Fabricate(:admin).tap { |u| Developer.create!(user_id: u.id) } }
  fab!(:user)
  fab!(:admin)

  after { Developer.rebuild_cache }

  describe "#index" do
    it "returns 200 for developers" do
      sign_in(developer)
      get "/dev-mode"
      expect(response.status).to eq(200)
    end

    it "returns 404 for anonymous users" do
      get "/dev-mode"
      expect(response.status).to eq(404)
    end

    it "returns 404 for normal users" do
      sign_in(user)
      get "/dev-mode"
      expect(response.status).to eq(404)
    end

    it "returns 404 for admins who are not developers" do
      sign_in(admin)
      get "/dev-mode"
      expect(response.status).to eq(404)
    end
  end

  describe "#enter" do
    it "sets _mp_auth cookie when enable_rack_mini_profiler param is present" do
      sign_in(developer)
      post "/dev-mode", params: { enable_rack_mini_profiler: "true" }

      expect(response.cookies["_mp_auth"]).to be_present
      expect(response).to redirect_to("/")
    end

    it "does not set cookie when enable_rack_mini_profiler param is absent" do
      sign_in(developer)
      post "/dev-mode"

      expect(response.cookies["_mp_auth"]).to be_nil
      expect(response).to redirect_to("/")
    end

    it "returns 404 for anonymous users" do
      post "/dev-mode", params: { enable_rack_mini_profiler: "true" }
      expect(response.status).to eq(404)
    end

    it "returns 404 for normal users" do
      sign_in(user)
      post "/dev-mode", params: { enable_rack_mini_profiler: "true" }
      expect(response.status).to eq(404)
    end

    it "returns 404 for admins who are not developers" do
      sign_in(admin)
      post "/dev-mode", params: { enable_rack_mini_profiler: "true" }
      expect(response.status).to eq(404)
    end
  end
end
