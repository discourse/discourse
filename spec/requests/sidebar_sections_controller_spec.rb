# frozen_string_literal: true

RSpec.describe SidebarSectionsController do
  fab!(:user)
  fab!(:admin)
  fab!(:moderator)

  describe "#index" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, title: "private section", user: user) }
    fab!(:sidebar_url_1) { Fabricate(:sidebar_url, name: "tags", value: "/tags") }
    fab!(:sidebar_url_2) { Fabricate(:sidebar_url, name: "categories", value: "/categories") }
    fab!(:section_link_1) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    end
    fab!(:sidebar_section_2) { Fabricate(:sidebar_section, title: "public section", public: true) }
    fab!(:section_link_2) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)
    end

    it "returns public and private sections" do
      sign_in(user)
      get "/sidebar_sections.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["sidebar_sections"].map { |section| section["title"] }).to eq(
        ["Community", "public section", "private section"],
      )
    end

    it "returns Community section first even when public sections are alphabetically before it" do
      sign_in(user)
      Fabricate(:sidebar_section, title: "Apple", public: true)

      get "/sidebar_sections.json"
      expect(response.status).to eq(200)

      titles = response.parsed_body["sidebar_sections"].map { |section| section["title"] }

      expect(titles).to eq(["Community", "Apple", "public section", "private section"])
    end
  end

  describe "#show" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, title: "Public section", public: true) }
    fab!(:sidebar_url) { Fabricate(:sidebar_url, name: "Sidebar Tags", value: "/tags") }

    before do
      Fabricate(:sidebar_section_link, sidebar_section:, linkable: sidebar_url)
      Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja", title: "公開セクション")
      Fabricate(:sidebar_url_localization, sidebar_url:, locale: "ja", name: "タグ")
    end

    it "returns source labels for admins editing a localized section" do
      SiteSetting.content_localization_enabled = true
      sign_in(admin)

      I18n.with_locale("ja") { get "/sidebar_sections/#{sidebar_section.id}.json" }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("sidebar_section", "title")).to eq("Public section")
      expect(response.parsed_body.dig("sidebar_section", "links", 0, "name")).to eq("Sidebar Tags")
      expect(response.parsed_body.dig("sidebar_section", "localizations", 0, "title")).to eq(
        "公開セクション",
      )
      expect(
        response.parsed_body.dig("sidebar_section", "links", 0, "localizations", 0, "name"),
      ).to eq("タグ")
    end

    it "returns localization rows only for manually created built-in section links" do
      SiteSetting.content_localization_enabled = true
      sign_in(admin)
      community_section =
        SidebarSection.find_by(section_type: SidebarSection.section_types[:community])
      topics_link = community_section.sidebar_urls.find_by(name: "Topics")
      manual_link = Fabricate(:sidebar_url, name: "Solutions", value: "/solutions", locale: "en")
      Fabricate(:sidebar_section_link, sidebar_section: community_section, linkable: manual_link)
      Fabricate(:sidebar_section_localization, sidebar_section: community_section, locale: "ja")
      Fabricate(:sidebar_url_localization, sidebar_url: topics_link, locale: "ja")
      Fabricate(:sidebar_url_localization, sidebar_url: manual_link, locale: "ja", name: "解決策")

      get "/sidebar_sections/#{community_section.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("sidebar_section", "localizations")).to eq(nil)
      links = response.parsed_body.dig("sidebar_section", "links")
      expect(links.find { |link| link["id"] == topics_link.id }["localizations"]).to eq(nil)
      expect(links.find { |link| link["id"] == topics_link.id }["can_localize"]).to eq(false)
      expect(
        links.find { |link| link["id"] == manual_link.id }["localizations"].first["name"],
      ).to eq("解決策")
      expect(links.find { |link| link["id"] == manual_link.id }["can_localize"]).to eq(true)
    end

    it "does not allow regular users to load a public section for editing" do
      sign_in(user)

      get "/sidebar_sections/#{sidebar_section.id}.json"

      expect(response.status).to eq(403)
    end
  end

  describe "#create" do
    it "is not available for anonymous" do
      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             links: [
               { icon: "link", name: "categories", value: "/categories" },
               { icon: "link", name: "tags", value: "/tags" },
             ],
           }
      expect(response.status).to eq(403)
    end

    it "creates custom section for user" do
      sign_in(user)
      expect(SidebarSection.count).to eq(1)

      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             links: [
               {
                 icon: "link",
                 name: "categories",
                 value: "http://#{Discourse.current_hostname}/categories",
               },
               { icon: "address-book", name: "tags", value: "/tags" },
               { icon: "up-right-from-square", name: "Discourse", value: "https://discourse.org" },
               { icon: "up-right-from-square", name: "My preferences", value: "/my/preferences" },
             ],
           }

      expect(response.status).to eq(200)

      expect(SidebarSection.count).to eq(2)
      sidebar_section = SidebarSection.last

      expect(sidebar_section.title).to eq("custom section")
      expect(sidebar_section.user).to eq(user)
      expect(sidebar_section.public).to be false
      expect(UserHistory.count).to eq(0)
      expect(sidebar_section.sidebar_urls.count).to eq(4)
      expect(sidebar_section.sidebar_urls.first.icon).to eq("link")
      expect(sidebar_section.sidebar_urls.first.name).to eq("categories")
      expect(sidebar_section.sidebar_urls.first.value).to eq("/categories")
      expect(sidebar_section.sidebar_urls.first.external).to be false
      expect(sidebar_section.sidebar_urls.second.icon).to eq("address-book")
      expect(sidebar_section.sidebar_urls.second.name).to eq("tags")
      expect(sidebar_section.sidebar_urls.second.value).to eq("/tags")
      expect(sidebar_section.sidebar_urls.second.external).to be false
      expect(sidebar_section.sidebar_urls.third.icon).to eq("up-right-from-square")
      expect(sidebar_section.sidebar_urls.third.name).to eq("Discourse")
      expect(sidebar_section.sidebar_urls.third.value).to eq("https://discourse.org")
      expect(sidebar_section.sidebar_urls.third.external).to be true
      expect(sidebar_section.sidebar_urls.fourth.icon).to eq("up-right-from-square")
      expect(sidebar_section.sidebar_urls.fourth.name).to eq("My preferences")
      expect(sidebar_section.sidebar_urls.fourth.value).to eq("/my/preferences")
      expect(sidebar_section.sidebar_urls.fourth.external).to be false
    end

    it "validates max number of links" do
      SiteSetting.max_sidebar_section_links = 5

      sign_in(user)

      links =
        6.times.map do
          { icon: "up-right-from-square", name: "My preferences", value: "/my/preferences" }
        end

      post "/sidebar_sections.json", params: { title: "custom section", links: links }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq(
        ["Maximum 5 records are allowed. Got 6 records instead."],
      )
    end

    it "does not allow regular user to create public section" do
      sign_in(user)

      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             public: true,
             links: [
               { icon: "link", name: "categories", value: "/categories" },
               { icon: "address-book", name: "tags", value: "/tags" },
             ],
           }

      expect(response.status).to eq(403)
    end

    it "does not allow regular user to create section localizations" do
      SiteSetting.content_localization_enabled = true
      sign_in(user)

      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             locale: "ja",
             localizations: [{ locale: "ja", title: "カスタム" }],
             links: [
               {
                 icon: "link",
                 name: "categories",
                 value: "/categories",
                 localizations: [{ locale: "ja", name: "カテゴリー" }],
               },
             ],
           }

      expect(response.status).to eq(200)

      sidebar_section = SidebarSection.last
      expect(sidebar_section.locale).to eq(SiteSetting.default_locale)
      expect(sidebar_section.localizations).to be_blank
      expect(sidebar_section.sidebar_urls.first.localizations).to be_blank
    end

    it "does not allow moderator to create public section" do
      sign_in(moderator)

      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             public: true,
             links: [
               { icon: "link", name: "categories", value: "/categories" },
               { icon: "address-book", name: "tags", value: "/tags" },
             ],
           }

      expect(response.status).to eq(403)
    end

    it "allows admin to create public section" do
      sign_in(admin)

      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             public: true,
             links: [
               { icon: "link", name: "categories", value: "/categories" },
               { icon: "address-book", name: "tags", value: "/tags" },
             ],
           }

      expect(response.status).to eq(200)

      sidebar_section = SidebarSection.last
      expect(sidebar_section.title).to eq("custom section")
      expect(sidebar_section.public).to be true
      expect(sidebar_section.user_id).to be Discourse.system_user.id

      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:create_public_sidebar_section])
      expect(user_history.subject).to eq("custom section")
      expect(user_history.details).to eq("links: categories - /categories, tags - /tags")
    end

    it "allows admin to create public section localizations" do
      SiteSetting.content_localization_enabled = true
      sign_in(admin)

      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             public: true,
             localizations: [
               { locale: SiteSetting.default_locale, title: "Default locale" },
               { locale: "ja", title: "カスタム" },
             ],
             links: [
               {
                 icon: "link",
                 name: "categories",
                 value: "/categories",
                 localizations: [
                   { locale: SiteSetting.default_locale, name: "Default locale" },
                   { locale: "ja", name: "カテゴリー" },
                 ],
               },
             ],
           }

      expect(response.status).to eq(200)

      sidebar_section = SidebarSection.last
      expect(sidebar_section.localizations.map { |localization| localization.title }).to eq(
        ["カスタム"],
      )
      expect(sidebar_section.sidebar_urls.first.localizations.map(&:name)).to eq(["カテゴリー"])
    end

    it "does not create localizations when content localization is disabled" do
      SiteSetting.content_localization_enabled = false
      sign_in(admin)

      post "/sidebar_sections.json",
           params: {
             title: "custom section",
             public: true,
             locale: "ja",
             localizations: [{ locale: "ja", title: "カスタム" }],
             links: [
               {
                 icon: "link",
                 name: "categories",
                 value: "/categories",
                 localizations: [{ locale: "ja", name: "カテゴリー" }],
               },
             ],
           }

      expect(response.status).to eq(200)

      sidebar_section = SidebarSection.last
      expect(sidebar_section.locale).to eq(SiteSetting.default_locale)
      expect(sidebar_section.localizations).to be_blank
      expect(sidebar_section.sidebar_urls.first.localizations).to be_blank
    end
  end

  describe "#update" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }
    fab!(:sidebar_url_1) { Fabricate(:sidebar_url, name: "tags", value: "/tags") }
    fab!(:sidebar_url_2) { Fabricate(:sidebar_url, name: "categories", value: "/categories") }

    fab!(:section_link_1) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    end

    fab!(:section_link_2) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)
    end

    let(:community_section) do
      SidebarSection.find_by(section_type: SidebarSection.section_types[:community])
    end

    it "allows user to update their own section and links" do
      sign_in(user)

      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [
              { icon: "link", id: sidebar_url_1.id, name: "latest", value: "/latest" },
              { icon: "link", id: sidebar_url_2.id, name: "tags", value: "/tags", _destroy: "1" },
            ],
          }

      expect(response.status).to eq(200)

      expect(sidebar_section.reload.title).to eq("custom section edited")
      expect(UserHistory.count).to eq(0)
      expect(sidebar_url_1.reload.name).to eq("latest")
      expect(sidebar_url_1.value).to eq("/latest")
      expect { section_link_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { sidebar_url_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not allow a user to update their own section locale" do
      SiteSetting.content_localization_enabled = true
      sign_in(user)

      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            locale: "ja",
            links: [{ icon: "link", id: sidebar_url_1.id, name: "latest", value: "/latest" }],
          }

      expect(response.status).to eq(200)
      expect(sidebar_section.reload.locale).to eq(SiteSetting.default_locale)
    end

    it "does not allow a user to update their own section localizations" do
      SiteSetting.content_localization_enabled = true
      sign_in(user)

      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            localizations: [{ locale: "ja", title: "カスタム" }],
            links: [
              {
                icon: "link",
                id: sidebar_url_1.id,
                name: "latest",
                value: "/latest",
                localizations: [{ locale: "ja", name: "最新" }],
              },
            ],
          }

      expect(response.status).to eq(403)
      expect(sidebar_section.reload.localizations).to be_blank
      expect(sidebar_url_1.reload.localizations).to be_blank
    end

    it "allows admin to update public section and links" do
      sign_in(admin)
      sidebar_section.update!(public: true)

      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [
              {
                icon: "link",
                name: "meta",
                value: "https://meta.discourse.org",
                segment: "primary",
              },
              { icon: "link", id: sidebar_url_1.id, name: "latest", value: "/latest" },
              { icon: "link", id: sidebar_url_2.id, name: "tags", value: "/tags", _destroy: "1" },
              {
                icon: "link",
                name: "homepage",
                value: "https://discourse.org",
                segment: "secondary",
              },
            ],
          }

      expect(response.status).to eq(200)

      expect(sidebar_section.reload.title).to eq("custom section edited")
      expect(sidebar_url_1.reload.name).to eq("latest")
      expect(sidebar_url_1.value).to eq("/latest")
      expect { section_link_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { sidebar_url_2.reload }.to raise_error(ActiveRecord::RecordNotFound)

      urls = sidebar_section.sidebar_urls
      expect(urls[0].name).to eq("meta")
      expect(urls[0].value).to eq("https://meta.discourse.org")
      expect(urls[0].segment).to eq("primary")
      expect(urls[1].name).to eq("latest")
      expect(urls[1].value).to eq("/latest")
      expect(urls[2].name).to eq("homepage")
      expect(urls[2].value).to eq("https://discourse.org")
      expect(urls[2].segment).to eq("secondary")

      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:update_public_sidebar_section])
      expect(user_history.subject).to eq("custom section edited")
      expect(user_history.details).to eq(
        "links: latest - /latest, meta - https://meta.discourse.org, homepage - https://discourse.org",
      )
    end

    it "allows admin to update public section localizations" do
      SiteSetting.content_localization_enabled = true
      SiteSetting.default_locale = "en"
      sign_in(admin)
      sidebar_section.update_columns(public: true, locale: nil)
      sidebar_url_1.update_column(:locale, nil)
      section_localization =
        Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja", title: "古い")
      url_localization =
        Fabricate(:sidebar_url_localization, sidebar_url: sidebar_url_1, locale: "ja", name: "古い")

      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            localizations: [
              { id: section_localization.id, locale: "ja", title: "新しい" },
              { locale: "fr", title: "Nouveau" },
              { locale: SiteSetting.default_locale, title: "Default locale" },
            ],
            links: [
              {
                icon: "link",
                id: sidebar_url_1.id,
                name: "latest",
                value: "/latest",
                localizations: [
                  { id: url_localization.id, locale: "ja", name: "最新" },
                  { locale: "fr", name: "Récent" },
                  { locale: SiteSetting.default_locale, name: "Default locale" },
                ],
              },
            ],
          }

      expect(response.status).to eq(200)
      expect(sidebar_section.reload.locale).to eq("en")
      expect(sidebar_url_1.reload.locale).to eq("en")
      expect(sidebar_section.reload.localizations.order(:locale).pluck(:locale, :title)).to eq(
        [%w[fr Nouveau], %w[ja 新しい]],
      )
      expect(sidebar_url_1.reload.localizations.order(:locale).pluck(:locale, :name)).to eq(
        [%w[fr Récent], %w[ja 最新]],
      )
    end

    it "does not allow admin to update built-in section localizations" do
      SiteSetting.content_localization_enabled = true
      sign_in(admin)
      topics_link = community_section.sidebar_urls.find_by(name: "Topics")

      put "/sidebar_sections/#{community_section.id}.json",
          params: {
            title: "community section edited",
            localizations: [{ locale: "ja", title: "コミュニティ" }],
            links: [
              {
                icon: "link",
                id: topics_link.id,
                name: "topics edited",
                value: "/latest",
                localizations: [{ locale: "ja", name: "トピック" }],
              },
            ],
          }

      expect(response.status).to eq(403)
      expect(community_section.reload.localizations).to be_blank
      expect(topics_link.reload.localizations).to be_blank
    end

    it "allows admin to update manually created Community section link localizations" do
      SiteSetting.content_localization_enabled = true
      sign_in(admin)
      manual_link = Fabricate(:sidebar_url, name: "Solutions", value: "/solutions", locale: "en")
      Fabricate(:sidebar_section_link, sidebar_section: community_section, linkable: manual_link)

      put "/sidebar_sections/#{community_section.id}.json",
          params: {
            title: "community section edited",
            links: [
              {
                icon: "link",
                id: manual_link.id,
                name: "Solutions",
                value: "/solutions",
                localizations: [{ locale: "ja", name: "解決策" }],
              },
            ],
          }

      expect(response.status).to eq(200)
      expect(manual_link.reload.localizations.order(:locale).pluck(:locale, :name)).to eq(
        [%w[ja 解決策]],
      )
    end

    it "allows admin to remove public section localizations" do
      SiteSetting.content_localization_enabled = true
      sign_in(admin)
      sidebar_section.update!(public: true)
      section_localization =
        Fabricate(:sidebar_section_localization, sidebar_section:, locale: "ja", title: "古い")
      url_localization =
        Fabricate(:sidebar_url_localization, sidebar_url: sidebar_url_1, locale: "ja", name: "古い")

      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            localizations: [
              { id: section_localization.id, locale: "ja", title: "古い", _destroy: "1" },
            ],
            links: [
              {
                icon: "link",
                id: sidebar_url_1.id,
                name: "latest",
                value: "/latest",
                localizations: [
                  { id: url_localization.id, locale: "ja", name: "古い", _destroy: "1" },
                ],
              },
            ],
          }

      expect(response.status).to eq(200)
      expect(SidebarSectionLocalization.exists?(section_localization.id)).to eq(false)
      expect(SidebarUrlLocalization.exists?(url_localization.id)).to eq(false)
    end

    it "validates limit of links" do
      SiteSetting.max_sidebar_section_links = 5

      sign_in(user)

      links =
        6.times.map do
          { icon: "up-right-from-square", name: "My preferences", value: "/my/preferences" }
        end

      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section",
            links: links,
          }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to eq(
        ["Maximum 5 records are allowed. Got 6 records instead."],
      )
    end

    it "returns 404 when updating a non-existent section" do
      sign_in(user)

      put "/sidebar_sections/99999999.json",
          params: {
            title: "custom section edited",
            links: [{ icon: "link", name: "latest", value: "/latest" }],
          }

      expect(response.status).to eq(404)
    end

    it "doesn't allow to edit other's sections" do
      sidebar_section_2 = Fabricate(:sidebar_section)
      sidebar_url_3 = Fabricate(:sidebar_url, name: "other_tags", value: "/tags")
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section_2, linkable: sidebar_url_3)
      sign_in(user)

      put "/sidebar_sections/#{sidebar_section_2.id}.json",
          params: {
            title: "custom section edited",
            links: [{ icon: "link", id: sidebar_url_3.id, name: "takeover", value: "/categories" }],
          }

      expect(response.status).to eq(403)
    end

    it "doesn't allow to edit public sections" do
      sign_in(user)
      sidebar_section.update!(public: true)

      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [
              { icon: "link", id: sidebar_url_1.id, name: "latest", value: "/latest" },
              { icon: "link", id: sidebar_url_2.id, name: "tags", value: "/tags", _destroy: "1" },
            ],
          }

      expect(response.status).to eq(403)
    end

    it "doesn't allow to edit other's links" do
      sidebar_url_3 = Fabricate(:sidebar_url, name: "other_tags", value: "/tags")

      Fabricate(
        :sidebar_section_link,
        sidebar_section: Fabricate(:sidebar_section),
        linkable: sidebar_url_3,
      )

      sign_in(user)

      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [{ icon: "link", id: sidebar_url_3.id, name: "takeover", value: "/categories" }],
          }

      expect(response.status).to eq(404)
      expect(sidebar_url_3.reload.name).to eq("other_tags")
    end

    it "doesn't allow users to edit community section" do
      sign_in(user)

      put "/sidebar_sections/#{community_section.id}.json",
          params: {
            title: "custom section edited",
            links: [],
          }

      expect(response.status).to eq(403)
    end

    it "allows admin to edit community section" do
      sign_in(admin)

      topics_link = community_section.sidebar_urls.find_by(name: "Topics")
      my_posts_link = community_section.sidebar_urls.find_by(name: "My posts")

      community_section
        .sidebar_section_links
        .where.not(linkable_id: [topics_link.id, my_posts_link.id])
        .destroy_all

      put "/sidebar_sections/#{community_section.id}.json",
          params: {
            title: "community section edited",
            links: [
              { icon: "link", id: my_posts_link.id, name: "my posts edited", value: "/my_posts" },
              { icon: "link", id: topics_link.id, name: "topics edited", value: "/new" },
            ],
          }

      expect(response.status).to eq(200)

      expect(community_section.reload.title).to eq("community section edited")
      expect(community_section.sidebar_urls[0].name).to eq("my posts edited")
      expect(community_section.sidebar_urls[0].value).to eq("/my_posts")
      expect(community_section.sidebar_urls[1].name).to eq("topics edited")
      expect(community_section.sidebar_urls[1].value).to eq("/new")
    end
  end

  describe "#destroy" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }

    let(:community_section) do
      SidebarSection.find_by(section_type: SidebarSection.section_types[:community])
    end

    it "allows user to delete their own section" do
      sign_in(user)
      delete "/sidebar_sections/#{sidebar_section.id}.json"

      expect(response.status).to eq(200)

      expect { sidebar_section.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect(UserHistory.count).to eq(0)
    end

    it "allows admin to delete public section" do
      sign_in(admin)
      sidebar_section.update!(public: true)
      delete "/sidebar_sections/#{sidebar_section.id}.json"

      expect(response.status).to eq(200)

      expect { sidebar_section.reload }.to raise_error(ActiveRecord::RecordNotFound)

      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:destroy_public_sidebar_section])
      expect(user_history.subject).to eq("Sidebar section")
    end

    it "returns 404 when deleting a non-existent section" do
      sign_in(user)
      delete "/sidebar_sections/99999999.json"

      expect(response.status).to eq(404)
    end

    it "doesn't allow to delete other's sidebar section" do
      sidebar_section_2 = Fabricate(:sidebar_section)
      sign_in(user)
      delete "/sidebar_sections/#{sidebar_section_2.id}.json"

      expect(response.status).to eq(403)
    end

    it "doesn't allow to delete public sidebar section" do
      sign_in(user)
      sidebar_section.update!(public: true)
      delete "/sidebar_sections/#{sidebar_section.id}.json"

      expect(response.status).to eq(403)
    end

    it "doesn't allow moderator to delete public sidebar section" do
      sign_in(moderator)
      sidebar_section.update!(public: true)
      delete "/sidebar_sections/#{sidebar_section.id}.json"

      expect(response.status).to eq(403)
    end
  end

  describe "#reset" do
    let(:community_section) do
      SidebarSection.find_by(section_type: SidebarSection.section_types[:community])
    end

    it "doesn't allow user to reset community section" do
      sign_in(user)
      SidebarSection.any_instance.expects(:reset_community!).never
      put "/sidebar_sections/reset/#{community_section.id}.json"
      expect(response.status).to eq(403)
    end

    it "doesn't allow staff to reset community section" do
      sign_in(moderator)
      SidebarSection.any_instance.expects(:reset_community!).never
      put "/sidebar_sections/reset/#{community_section.id}.json"
      expect(response.status).to eq(403)
    end

    it "allows admins to reset community section to default" do
      sign_in(admin)
      SidebarSection.any_instance.expects(:reset_community!).once
      put "/sidebar_sections/reset/#{community_section.id}.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["sidebar_section"]["id"]).to eq(community_section.id)
      expect(response.parsed_body["sidebar_section"]["title"]).to eq(community_section.title)
    end

    it "doesn't allow admin to delete community sidebar section" do
      sign_in(admin)
      delete "/sidebar_sections/#{community_section.id}.json"

      expect(response.status).to eq(403)
    end
  end
end
