# frozen_string_literal: true

RSpec.describe ForumsController do
  describe "read only header" do
    it "returns no read only header by default" do
      get "/srv/status"
      expect(response.status).to eq(200)
      expect(response.headers["Discourse-Readonly"]).to eq(nil)
    end

    it "returns a readonly header if the site is read only" do
      Discourse.received_postgres_readonly!
      get "/srv/status"
      expect(response.status).to eq(200)
      expect(response.headers["Discourse-Readonly"]).to eq("true")
    end

    it "returns a readonly header if the site is in staff-writes-only mode" do
      Discourse.stubs(:staff_writes_only_mode?).returns(true)
      get "/srv/status"
      expect(response.status).to eq(200)
      expect(response.headers["Discourse-Readonly"]).to eq("true")
    end
  end

  describe "cluster parameter" do
    it "returns a 500 response if the cluster is not configured" do
      get "/srv/status?cluster=abc"
      expect(response.status).to eq(500)
      expect(response.body).to include("not configured")
    end

    it "returns a 500 response if the cluster does not match" do
      global_setting(:cluster_name, "mycluster")
      get "/srv/status?cluster=abc"
      expect(response.status).to eq(500)
      expect(response.body).to include("not match")
    end

    it "returns a 200 response if the cluster does match" do
      global_setting(:cluster_name, "mycluster")
      get "/srv/status?cluster=abc"
      expect(response.status).to eq(500)
      expect(response.body).to include("not match")
    end

    it "returns a 200 response when given shutdown_ok" do
      get "/srv/status?shutdown_ok=1"
      expect(response.status).to eq(200)
    end
  end
end
