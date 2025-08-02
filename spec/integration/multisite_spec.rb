# frozen_string_literal: true

RSpec.describe "multisite", type: %i[multisite request] do
  it "should always allow /srv/status through" do
    get "http://unknown.com/srv/status"
    expect(response.status).to eq(200)
    expect(request.env["HTTP_HOST"]).to eq("test.localhost") # Rewritten by EnforceHostname middleware
  end

  it "should 404 for unknown domains" do
    get "http://unknown.com/about.json"
    expect(response.status).to eq(404)
  end

  it "should hit correct site otherwise" do
    site_1_url =
      Fabricate(:topic, title: "Site 1 Topic Title", user: Discourse.system_user).relative_url

    test_multisite_connection("second") do
      site_2_url =
        Fabricate(:topic, title: "Site 2 Topic Title", user: Discourse.system_user).relative_url

      get "http://test.localhost/#{site_1_url}.json"
      expect(request.env["RAILS_MULTISITE_HOST"]).to eq("test.localhost")
      expect(response.status).to eq(200)
      expect(response.parsed_body["title"]).to eq("Site 1 Topic Title")

      get "http://test2.localhost/#{site_2_url}.json"
      expect(response.status).to eq(200)
      expect(request.env["RAILS_MULTISITE_HOST"]).to eq("test2.localhost")
      expect(response.parsed_body["title"]).to eq("Site 2 Topic Title")
    end
  end
end
