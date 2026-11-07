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

  let(:suggestions) { Lovelace::Checklist.seeded_items }

  before { enable_current_plugin }

  describe "#admin_show" do
    it "seeds the editable checklist and supplies the notification suggestion" do
      sign_in(admin)
      topic = Fabricate(:topic)
      SiteSetting.guidelines_topic_id = topic.id

      get "/lovelace/admin/checklist.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["revision"]).to eq(0)
      expect(response.parsed_body["unmodified_seed_ids"]).to eq(
        %w[profile_picture profile guidelines],
      )
      expect(response.parsed_body["items"]).to eq(
        [
          {
            "id" => "profile_picture",
            "title" => "Add a profile picture",
            "description" => "Add a picture to make your profile stand out.",
            "button_text" => "Add picture",
            "link_type" => "account",
            "url" => "/my/preferences/account",
          },
          {
            "id" => "profile",
            "title" => "Complete your profile",
            "description" => "Fill out your bio and other details so we can get to know you.",
            "button_text" => "Complete profile",
            "link_type" => "profile",
            "url" => "/my/preferences/profile",
          },
          {
            "id" => "guidelines",
            "title" => "Read community guidelines",
            "description" => "Learn about our community and how to participate here.",
            "button_text" => "Read guidelines",
            "link_type" => "custom",
            "url" => topic.relative_url,
          },
        ],
      )
      expect(response.parsed_body["bank"]).to eq(
        [
          {
            "id" => "notifications",
            "title" => "Set up your notifications",
            "description" => "Turn on push notifications to keep up to speed with the community.",
            "button_text" => "Set up notifications",
            "link_type" => "notifications",
            "url" => "/my/preferences/notifications",
          },
        ],
      )
    end

    it "preserves existing editable checklists and makes unused suggestions available" do
      PluginStore.set(
        Lovelace::PLUGIN_NAME,
        "checklist",
        { "items" => [item.stringify_keys], "revision" => 7 },
      )
      sign_in(admin)

      get "/lovelace/admin/checklist.json"

      expect(response.parsed_body).to eq(
        "items" => [item.stringify_keys],
        "revision" => 7,
        "bank" => suggestions,
        "unmodified_seed_ids" => [],
      )
    end

    it "restricts configuration to administrators" do
      PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => [], "revision" => 0 })
      get "/lovelace/admin/checklist.json"
      expect(response.status).to eq(403)

      sign_in(user)
      get "/lovelace/admin/checklist.json"
      expect(response.status).to eq(403)

      sign_in(admin)
      get "/lovelace/admin/checklist.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        "items" => [],
        "revision" => 0,
        "bank" => suggestions,
        "unmodified_seed_ids" => [],
      )

      SiteSetting.lovelace_enabled = false
      get "/lovelace/admin/checklist.json"
      expect(response.status).to eq(404)
    end
  end

  describe "#admin_update" do
    it "identifies unchanged suggestions after saves and reloads and excludes every customized field" do
      sign_in(admin)
      seed = suggestions.first
      changed_fields = {
        "title" => "Choose your avatar",
        "description" => "Introduce yourself with a picture.",
        "button_text" => "Choose picture",
        "url" => "/welcome",
        "link_type" => "custom",
      }
      changed_fields.each_with_index do |(field, value), revision|
        original =
          field == "url" ? suggestions.find { |suggestion| suggestion["id"] == "guidelines" } : seed
        customized = original.merge(field => value)
        put "/lovelace/admin/checklist.json",
            params: {
              items: [customized],
              revision: revision,
            },
            as: :json
        expect(response.status).to eq(200)
        expect(response.parsed_body["unmodified_seed_ids"]).to eq([])
        get "/lovelace/admin/checklist.json"
        expect(response.parsed_body["unmodified_seed_ids"]).to eq([])
      end

      put "/lovelace/admin/checklist.json",
          params: {
            items: [*suggestions, item.stringify_keys],
            revision: changed_fields.size,
          },
          as: :json
      expect(response.status).to eq(200)
      expect(response.parsed_body["unmodified_seed_ids"]).to eq(
        %w[profile_picture profile guidelines notifications],
      )
      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body["unmodified_seed_ids"]).to eq(
        %w[profile_picture profile guidelines notifications],
      )
    end

    it "returns edited defaults to the bank and restores them without losing edits" do
      sign_in(admin)
      get "/lovelace/admin/checklist.json"
      initial = response.parsed_body
      edited =
        initial["items"].first.merge(
          "title" => "Choose your avatar",
          "description" => "Let people recognize you.",
          "button_text" => "Choose picture",
        )
      remaining = initial["items"].drop(1)

      put "/lovelace/admin/checklist.json",
          params: {
            items: [edited, *remaining],
            revision: 0,
          },
          as: :json
      expect(response.status).to eq(200)
      put "/lovelace/admin/checklist.json", params: { items: remaining, revision: 1 }, as: :json
      expect(response.status).to eq(200)
      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body["bank"]).to eq([edited, *initial["bank"]])
      expect(response.parsed_body["items"]).to eq(remaining)

      put "/lovelace/admin/checklist.json",
          params: {
            items: [*remaining, edited, *initial["bank"]],
            revision: 2,
          },
          as: :json
      expect(response.status).to eq(200)
      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body["items"]).to eq([*remaining, edited, *initial["bank"]])
      expect(response.parsed_body["bank"]).to eq([])

      put "/lovelace/admin/checklist.json", params: { items: [], revision: 3 }, as: :json
      expect(response.status).to eq(200)
      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body["items"]).to eq([])
      expect(response.parsed_body["bank"].map { |entry| entry["id"] }).to eq(
        %w[profile_picture profile guidelines notifications],
      )
      expect(response.parsed_body["bank"].first).to eq(edited)
    end

    it "keeps both the checklist and the bank when a stale bank addition arrives" do
      sign_in(admin)
      get "/lovelace/admin/checklist.json"
      initial = response.parsed_body
      put "/lovelace/admin/checklist.json", params: { items: [], revision: 0 }, as: :json
      saved = response.parsed_body

      put "/lovelace/admin/checklist.json",
          params: {
            items: [*initial["items"], *initial["bank"]],
            revision: 0,
          },
          as: :json

      expect(response.status).to eq(409)
      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body).to eq(saved)
    end

    it "keeps editable items separate from member checklist selections" do
      sign_in(admin)
      put "/lovelace/checklist.json", params: { item_ids: %w[notifications] }, as: :json
      expect(response.status).to eq(200)

      put "/lovelace/admin/checklist.json", params: { items: [item], revision: 0 }, as: :json
      expect(response.status).to eq(200)

      get "/lovelace/checklist.json"
      expect(response.parsed_body["items"].map { |entry| entry["id"] }).to eq(%w[notifications])

      put "/lovelace/checklist.json", params: { item_ids: [] }, as: :json
      expect(response.status).to eq(200)

      get "/lovelace/admin/checklist.json"
      expect(response.parsed_body).to eq(
        "items" => [item.stringify_keys],
        "revision" => 1,
        "bank" => suggestions,
        "unmodified_seed_ids" => [],
      )
    end

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
      PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", { "items" => [], "revision" => 0 })
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

  describe "#show" do
    it "starts with three defaults and a notification suggestion for admins" do
      sign_in(admin)

      get "/lovelace/checklist.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["items"].map { |item| item["id"] }).to eq(
        %w[profile_picture profile guidelines],
      )
      expect(response.parsed_body["bank"].map { |item| item["id"] }).to eq(%w[notifications])
      expect(response.parsed_body["items"].first).to include(
        "title" => "Add a profile picture",
        "description" => "Add a picture to make your profile stand out.",
        "button_text" => "Add picture",
      )
    end

    it "links to the current member's preferences and guidelines topic" do
      topic = Fabricate(:topic)
      SiteSetting.guidelines_topic_id = topic.id
      Lovelace::Checklist.update!(Lovelace::Checklist::ITEMS)
      sign_in(user)

      get "/lovelace/checklist.json"

      expect(response.parsed_body["items"].map { |item| item["url"] }).to eq(
        [
          "/u/#{user.username_lower}/preferences/account",
          "/u/#{user.username_lower}/preferences/profile",
          topic.relative_url,
          "/u/#{user.username_lower}/preferences/notifications",
        ],
      )
      expect(response.parsed_body).not_to have_key("bank")
    end

    it "uses the guidelines page when no topic is configured" do
      SiteSetting.guidelines_topic_id = 0
      sign_in(user)

      get "/lovelace/checklist.json"

      expect(response.parsed_body["items"].last["url"]).to eq("/guidelines")
    end

    it "requires a signed-in member" do
      get "/lovelace/checklist.json"

      expect(response.status).to eq(403)
    end

    it "rejects requests when disabled" do
      sign_in(user)
      SiteSetting.lovelace_enabled = false

      get "/lovelace/checklist.json"

      expect(response.status).to eq(404)
    end
  end

  describe "#update" do
    it "persists selection, returns removed defaults to the bank, and restores them" do
      sign_in(admin)

      put "/lovelace/checklist.json", params: { item_ids: %w[profile guidelines notifications] }

      expect(response.status).to eq(200)
      expect(response.parsed_body["bank"].map { |item| item["id"] }).to eq(%w[profile_picture])

      get "/lovelace/checklist.json"
      expect(response.parsed_body["items"].map { |item| item["id"] }).to eq(
        %w[profile guidelines notifications],
      )

      put "/lovelace/checklist.json", params: { item_ids: Lovelace::Checklist::ITEMS }
      expect(response.parsed_body["bank"]).to eq([])
    end

    it "preserves an intentionally empty checklist" do
      sign_in(admin)

      put "/lovelace/checklist.json", params: { item_ids: [] }, as: :json
      get "/lovelace/checklist.json"

      expect(response.parsed_body["items"]).to eq([])
      expect(response.parsed_body["bank"].length).to eq(4)
    end

    it "rejects invalid and duplicate items without changing the checklist" do
      sign_in(admin)

      [%w[unknown], %w[profile profile], "profile", nil].each do |ids|
        put "/lovelace/checklist.json", params: { item_ids: ids }, as: :json
        expect(response.status).to eq(400)
      end

      expect(Lovelace::Checklist.item_ids).to eq(Lovelace::Checklist::DEFAULT_ITEMS)
    end

    it "forbids regular members and moderators from configuring the checklist" do
      [user, Fabricate(:moderator)].each do |member|
        sign_in(member)

        put "/lovelace/checklist.json", params: { item_ids: %w[notifications] }

        expect(response.status).to eq(403)
      end
      expect(Lovelace::Checklist.item_ids).to eq(Lovelace::Checklist::DEFAULT_ITEMS)
    end
  end
end
