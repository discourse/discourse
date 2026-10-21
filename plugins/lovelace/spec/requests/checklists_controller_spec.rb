# frozen_string_literal: true

RSpec.describe Lovelace::ChecklistsController do
  fab!(:admin)
  fab!(:user)

  let(:item) do
    {
      id: "first",
      title: "Introduce yourself",
      description: "Say hello to the community.",
      link_type: "topic",
      url: "/t/welcome/123",
      button_text: "Say hello",
    }
  end

  before { enable_current_plugin }

  describe "#show" do
    it "restricts configuration to administrators" do
      get "/lovelace/admin/checklist.json"
      expect(response.status).to eq(403)

      sign_in(user)
      get "/lovelace/admin/checklist.json"
      expect(response.status).to eq(403)

      sign_in(admin)
      get "/lovelace/admin/checklist.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq("items" => [], "revision" => 0)

      SiteSetting.lovelace_enabled = false
      get "/lovelace/admin/checklist.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#update" do
    it "lets administrators save, reorder, edit, and remove items" do
      sign_in(admin)
      second = item.merge(id: "second", title: "Add a picture", link_type: "profile", url: "")
      put "/lovelace/admin/checklist.json",
          params: {
            items: [item, second],
            revision: 0,
          },
          as: :json
      expect(response.status).to eq(200)
      expect(response.parsed_body["items"].last["url"]).to eq("/my/preferences/profile")

      put "/lovelace/admin/checklist.json",
          params: {
            items: [second, item.merge(title: "Welcome")],
            revision: 1,
          },
          as: :json
      expect(response.status).to eq(200)
      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body["items"].map { |entry| entry["title"] }).to eq(
        ["Add a picture", "Welcome"],
      )

      put "/lovelace/admin/checklist.json", params: { items: [], revision: 2 }, as: :json
      expect(response.status).to eq(200)
      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body["items"]).to eq([])
    end

    it "rejects writes from non-administrators and when disabled" do
      put "/lovelace/admin/checklist.json", params: { items: [item], revision: 0 }, as: :json
      expect(response.status).to eq(403)
      sign_in(user)
      put "/lovelace/admin/checklist.json", params: { items: [item], revision: 0 }, as: :json
      expect(response.status).to eq(403)
      sign_in(admin)
      SiteSetting.lovelace_enabled = false
      put "/lovelace/admin/checklist.json", params: { items: [item], revision: 0 }, as: :json
      expect(response.status).to eq(404)
    end

    it "keeps the saved configuration when a stale update arrives" do
      sign_in(admin)
      put "/lovelace/admin/checklist.json", params: { items: [item], revision: 0 }, as: :json
      put "/lovelace/admin/checklist.json", params: { items: [], revision: 0 }, as: :json
      expect(response.status).to eq(409)
      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body["items"].first["title"]).to eq(item[:title])
    end

    it "rejects invalid items without changing saved data" do
      sign_in(admin)
      invalid_items = [
        item.merge(url: "javascript:alert(1)"),
        item.merge(link_type: "custom", url: "//example.com"),
        item.merge(link_type: "custom", url: "/\\example.com"),
        item.merge(title: " "),
        item.merge(title: "a" * 121),
        item.merge(link_type: "unknown"),
        item.merge(url: "/u/admin"),
      ]
      invalid_items.each do |invalid_item|
        put "/lovelace/admin/checklist.json",
            params: {
              items: [invalid_item],
              revision: 0,
            },
            as: :json
        expect(response.status).to eq(400)
      end
      put "/lovelace/admin/checklist.json", params: { items: [item, item], revision: 0 }, as: :json
      expect(response.status).to eq(400)
      put "/lovelace/admin/checklist.json",
          params: {
            items: Array.new(51) { item },
            revision: 0,
          },
          as: :json
      expect(response.status).to eq(400)
      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body["items"]).to eq([])
    end

    it "accepts each supported link destination" do
      sign_in(admin)
      destinations = {
        "custom" => "https://example.com/welcome",
        "category" => "/c/general/1",
        "topic" => "/t/welcome/123",
        "chat" => "/chat/c/general/1",
        "profile" => "",
        "notifications" => "",
        "account" => "",
      }
      destinations.each_with_index do |(type, url), revision|
        put "/lovelace/admin/checklist.json",
            params: {
              items: [item.merge(link_type: type, url: url)],
              revision: revision,
            },
            as: :json
        expect(response.status).to eq(200)
      end
    end
  end
end
