# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::SearchDiscourseNavigation do
  fab!(:admin)
  fab!(:user)

  before { enable_current_plugin }

  def search(query, user: admin, url: nil)
    described_class.new(
      { query: query, url: url },
      bot_user: Discourse.system_user,
      llm: nil,
      context: DiscourseAi::Agents::BotContext.new(user: user),
    ).invoke
  end

  describe "#invoke" do
    it "returns canonical destinations for task keywords" do
      expect(search("themes")[:destinations]).to contain_exactly(
        {
          id: "core:themes",
          title: "Themes",
          description: I18n.t("discourse_ai.ai_bot.navigation.themes.description"),
          url: "#{Discourse.base_url}/admin/config/customize/themes",
        },
      )
      expect(search("invite")[:destinations].pluck(:url)).to eq(
        ["#{Discourse.base_url}/new-invite"],
      )
    end

    it "uses the current installation base path without caching resolved URLs" do
      original_url = search("backups")[:destinations].first[:url]
      set_subfolder "/community"

      expect(search("backups")[:destinations].first[:url]).to eq(
        "#{Discourse.base_url}/admin/backups",
      )
      expect(search("backups")[:destinations].first[:url]).not_to eq(original_url)
    end

    it "verifies exact navigation URLs and corrects appended numbers" do
      url = "#{Discourse.base_url}/admin/backups"

      expect(search("backups", url: url)[:url_verification]).to eq(
        verified: true,
        canonical_url: url,
      )
      expect(search("backups", url: "#{url}/123")[:url_verification]).to eq(
        verified: false,
        canonical_url: url,
      )
    end

    it "verifies subcategory URLs without allowing appended IDs, queries, or fragments" do
      set_subfolder "/community"
      parent = Fabricate(:category, name: "Support")
      category = Fabricate(:category, name: "Questions", parent_category: parent)
      url = "#{Discourse.base_url}/c/support/questions/#{category.id}"

      expect(search("Questions", url: url)[:url_verification]).to eq(
        verified: true,
        canonical_url: url,
      )
      ["/#{category.id}", "?page=2", "#123"].each do |suffix|
        expect(search("Questions", url: "#{url}#{suffix}")[:url_verification]).to eq(
          verified: false,
          canonical_url: url,
        )
      end
    end

    it "leaves unavailable, unknown, and external destinations unverified" do
      SiteSetting.tagging_enabled = false
      category = Fabricate(:category)

      [
        "#{Discourse.base_url}/tags",
        "#{Discourse.base_url}/admin/unknown",
        "#{Discourse.base_url}/admin/backups123",
        "https://example.com#{category.url}",
        "#{Discourse.base_url}/c/wrong-slug/#{category.id}",
      ].each do |url|
        expect(search("categories", url: url)[:url_verification]).to eq(
          verified: false,
          canonical_url: nil,
        )
      end
    end

    it "omits destinations disabled on this site" do
      SiteSetting.tagging_enabled = false

      expect(search("tags")[:destinations]).to eq([])
    end

    it "searches translated titles as well as English metadata" do
      TranslationOverride.upsert!("fr", "discourse_ai.ai_bot.navigation.themes.title", "Apparence")

      I18n.with_locale(:fr) do
        expect(search("apparence")[:destinations].pluck(:id, :title)).to eq(
          [%w[core:themes Apparence]],
        )
        expect(search("themes")[:destinations].pluck(:id)).to eq(["core:themes"])
      end
    end

    it "uses the requesting user's permissions instead of the bot's" do
      expect(search("themes", user: user)[:status]).to eq("error")
    end

    it "returns no destination for an unknown page" do
      expect(search("nonexistent-destination")[:destinations]).to eq([])
    end

    it "rejects empty and oversized queries" do
      [nil, "  ", "a" * (described_class::MAX_QUERY_LENGTH + 1)].each do |query|
        expect(search(query)[:status]).to eq("error")
      end
    end

    it "bounds results and ranks destinations matching more keywords first" do
      results =
        search(
          "themes appearance design site manage users groups review invite categories tags backups",
        )[
          :destinations
        ]

      expect(results.size).to eq(described_class::MAX_RESULTS)
      expect(results.first[:id]).to eq("core:themes")
    end

    it "finds plugin aliases only while the plugin and its destination are available" do
      plugin = Plugin::Instance.new(Plugin::Metadata.parse("# name: navigation-test"))
      plugin.enabled_site_setting(:discourse_sample_plugin_enabled)
      registry = DiscoursePluginRegistry._raw_navigation_destinations
      original_entries = registry.dup

      begin
        plugin.register_navigation_destination(
          "portal",
          path: "/admin/example-portal",
          title: "discourse_ai.ai_bot.navigation.settings.title",
          description: "discourse_ai.ai_bot.navigation.settings.description",
          keywords: ["example-subscription"],
        ) { |guardian| guardian.user.id == admin.id && SiteSetting.allow_user_locale }

        SiteSetting.discourse_sample_plugin_enabled = true
        SiteSetting.allow_user_locale = true
        expect(search("example-subscription")[:destinations].pluck(:id, :url)).to eq(
          [["navigation-test:portal", "#{Discourse.base_url}/admin/example-portal"]],
        )

        SiteSetting.allow_user_locale = false
        expect(search("example-subscription")[:destinations]).to eq([])

        SiteSetting.allow_user_locale = true
        SiteSetting.discourse_sample_plugin_enabled = false
        expect(search("example-subscription")[:destinations]).to eq([])
      ensure
        registry.replace(original_entries)
      end
    end
  end
end
