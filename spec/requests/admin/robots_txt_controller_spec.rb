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

    it "can't see #update" do
      put "/admin/customize/robots.json", params: { content: "adasdasd" }
      expect(response.status).to eq(404)
      expect(SiteSetting.overridden_robots_txt).to eq("")
    end
  end

  describe "#show" do
    before { sign_in(admin) }

    it "returns default content is there are no overrides" do
      get "/admin/customize/robots.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["content"]).to be_present
      expect(json["overridden"]).to eq(false)
    end

    it "returns overridden content if there are overrides" do
      SiteSetting.overridden_robots_txt = "something"
      get "/admin/customize/robots.json"
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["content"]).to eq("something")
      expect(json["overridden"]).to eq(true)
    end
  end

  describe "#update" do
    before { sign_in(admin) }

    it "overrides the site's default robots.txt" do
      put "/admin/customize/robots.json", params: { content: "new_content" }
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["content"]).to eq("new_content")
      expect(json["overridden"]).to eq(true)
      expect(SiteSetting.overridden_robots_txt).to eq("new_content")

      get "/robots.txt"
      expect(response.body).to eq("new_content")
    end

    it "allows reverting changes" do
      SiteSetting.overridden_robots_txt = "overridden_content"
      put "/admin/customize/robots.json", params: { content: "" }
      expect(response.status).to eq(200)
      json = JSON.parse(response.body)
      expect(json["content"]).not_to eq("overridden_content")
      expect(json["overridden"]).to eq(false)
      expect(SiteSetting.overridden_robots_txt).to eq("")

      get "/robots.txt"
      expect(response.body).not_to eq("overridden_content")
    end
  end
end
