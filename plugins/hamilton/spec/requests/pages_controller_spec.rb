# frozen_string_literal: true

RSpec.describe Hamilton::PagesController do
  before { enable_current_plugin }

  describe "#index" do
    it "serves the greeting page" do
      get "/hamilton"
      expect(response.status).to eq(200)
    end

    it "requires login on a private site" do
      SiteSetting.login_required = true

      get "/hamilton"
      expect(response).to redirect_to("/login")
    end
  end

  describe "#docs" do
    it "serves the README publicly even when login is required" do
      SiteSetting.login_required = true

      get "/hamilton/docs"
      expect(response.status).to eq(200)

      get "/hamilton/docs.json"
      expect(response.status).to eq(200)
      html = Nokogiri::HTML5.fragment(response.parsed_body.fetch("html"))
      expect(html.at_css("h1").text).to eq("Hamilton")
      expect(html.text).to include("Hamilton adds a configurable greeting")
      expect(html.at_css('a[href="/hamilton/docs/guide"]').text).to eq("Hamilton guide")
      expect(html.at_css('a[href="/hamilton/docs/roadmap"]').text).to eq("Roadmap")
    end

    it "returns 404 when Hamilton is disabled" do
      SiteSetting.hamilton_enabled = false

      %w[
        /hamilton
        /hamilton/docs
        /hamilton/docs.json
        /hamilton/docs/guide.json
        /hamilton/docs/roadmap
        /hamilton/docs/roadmap.json
      ].each do |path|
        get path
        expect(response.status).to eq(404)
      end
    end
  end

  describe "#guide" do
    it "serves the product guide publicly" do
      SiteSetting.login_required = true

      get "/hamilton/docs/guide.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body.fetch("html")).to include("Installation and configuration")
    end
  end

  describe "#roadmap" do
    it "serves the roadmap publicly even when login is required" do
      SiteSetting.login_required = true

      get "/hamilton/docs/roadmap"
      expect(response.status).to eq(200)

      get "/hamilton/docs/roadmap.json"
      expect(response.status).to eq(200)
      html = Nokogiri::HTML5.fragment(response.parsed_body.fetch("html"))
      expect(html.at_css("h1").text).to eq("Roadmap")
      expect(html.css("h2").map(&:text)).to eq(%w[Overview Goals Milestones])
      expect(html.text).to include("bathtub", "thermostat", "draggable time cursor")
    end
  end
end
