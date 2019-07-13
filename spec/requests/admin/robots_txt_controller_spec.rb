# frozen_string_literal: true

require 'rails_helper'

describe Admin::RobotsTxtController do
  it "is a subclass of AdminController" do
    expect(described_class < Admin::AdminController).to eq(true)
  end

  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }

  describe "non-admin users" do
    before { sign_in(user) }

    it "can't see #show" do
      get "/admin/customize/robots.json"
      expect(response.status).to eq(404)
    end

    it "can't perform #update" do
      put "/admin/customize/robots.json", params: { robots_txt: "adasdasd" }
      expect(response.status).to eq(404)
      expect(SiteSetting.overridden_robots_txt).to eq("")
    end

    it "can't perform #reset" do
      SiteSetting.overridden_robots_txt = "overridden_content"
      delete "/admin/customize/robots.json"
      expect(response.status).to eq(404)
      expect(SiteSetting.overridden_robots_txt).to eq("overridden_content")
    end
  end

  describe "#show" do
    before { sign_in(admin) }

    it "returns default content if there are no overrides" do
      get "/admin/customize/robots.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["robots_txt"]).to be_present
      expect(json["overridden"]).to eq(false)
    end

    it "returns overridden content if there are overrides" do
      SiteSetting.overridden_robots_txt = "something"
      get "/admin/customize/robots.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["robots_txt"]).to eq("something")
      expect(json["overridden"]).to eq(true)
    end
  end

  describe "#update" do
    before { sign_in(admin) }

    it "overrides the site's default robots.txt" do
      put "/admin/customize/robots.json", params: { robots_txt: "new_content" }
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["robots_txt"]).to eq("new_content")
      expect(json["overridden"]).to eq(true)
      expect(SiteSetting.overridden_robots_txt).to eq("new_content")

      get "/robots.txt"
      expect(response.body).to include("new_content")
    end

    it "requires `robots_txt` param to be present" do
      SiteSetting.overridden_robots_txt = "overridden_content"
      put "/admin/customize/robots.json", params: { robots_txt: "" }
      expect(response.status).to eq(400)
    end
  end

  describe "#reset" do
    before { sign_in(admin) }

    it "resets robots.txt file to the default version" do
      SiteSetting.overridden_robots_txt = "overridden_content"
      delete "/admin/customize/robots.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["robots_txt"]).not_to include("overridden_content")
      expect(json["overridden"]).to eq(false)
      expect(SiteSetting.overridden_robots_txt).to eq("")
    end
  end
end
