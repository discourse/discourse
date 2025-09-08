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
      Discourse.enable_readonly_mode(Discourse::STAFF_WRITES_ONLY_MODE_KEY)
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
      get "/srv/status?cluster=mycluster"
      expect(response.status).to eq(200)
      expect(response.body).not_to include("not match")
    end
  end
end
