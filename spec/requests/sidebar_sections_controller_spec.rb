# frozen_string_literal: true

RSpec.describe SidebarSectionsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:admin) { Fabricate(:admin) }

  before do
    ### TODO remove when enable_custom_sidebar_sections SiteSetting is removed
    group = Fabricate(:group)
    Fabricate(:group_user, group: group, user: user)
    Fabricate(:group_user, group: group, user: admin)
    SiteSetting.enable_custom_sidebar_sections = group.id.to_s
  end

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
        ["public section", "private section"],
      )
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
               { icon: "external-link-alt", name: "Discourse", value: "https://discourse.org" },
               { icon: "external-link-alt", name: "My preferences", value: "/my/preferences" },
             ],
           }

      expect(response.status).to eq(200)

      expect(SidebarSection.count).to eq(1)
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
      expect(sidebar_section.sidebar_urls.third.icon).to eq("external-link-alt")
      expect(sidebar_section.sidebar_urls.third.name).to eq("Discourse")
      expect(sidebar_section.sidebar_urls.third.value).to eq("https://discourse.org")
      expect(sidebar_section.sidebar_urls.third.external).to be true
      expect(sidebar_section.sidebar_urls.fourth.icon).to eq("external-link-alt")
      expect(sidebar_section.sidebar_urls.fourth.name).to eq("My preferences")
      expect(sidebar_section.sidebar_urls.fourth.value).to eq("/my/preferences")
      expect(sidebar_section.sidebar_urls.fourth.external).to be false
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

    it "allows admin to update public section and links" do
      sign_in(admin)
      sidebar_section.update!(public: true)
      put "/sidebar_sections/#{sidebar_section.id}.json",
          params: {
            title: "custom section edited",
            links: [
              { icon: "link", id: sidebar_url_1.id, name: "latest", value: "/latest" },
              { icon: "link", id: sidebar_url_2.id, name: "tags", value: "/tags", _destroy: "1" },
              { icon: "link", name: "homepage", value: "https://discourse.org" },
            ],
          }

      expect(response.status).to eq(200)

      expect(sidebar_section.reload.title).to eq("custom section edited")
      expect(sidebar_url_1.reload.name).to eq("latest")
      expect(sidebar_url_1.value).to eq("/latest")
      expect { section_link_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { sidebar_url_2.reload }.to raise_error(ActiveRecord::RecordNotFound)

      expect(sidebar_section.sidebar_section_links.last.position).to eq(2)
      expect(sidebar_section.sidebar_section_links.last.linkable.name).to eq("homepage")
      expect(sidebar_section.sidebar_section_links.last.linkable.value).to eq(
        "https://discourse.org",
      )

      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:update_public_sidebar_section])
      expect(user_history.subject).to eq("custom section edited")
      expect(user_history.details).to eq(
        "links: latest - /latest, homepage - https://discourse.org",
      )
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
  end

  describe "#reorder" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }
    fab!(:sidebar_url_1) { Fabricate(:sidebar_url, name: "tags", value: "/tags") }
    fab!(:sidebar_url_2) { Fabricate(:sidebar_url, name: "categories", value: "/categories") }
    fab!(:sidebar_url_3) { Fabricate(:sidebar_url, name: "topic", value: "/t/1") }
    fab!(:section_link_1) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_1)
    end
    fab!(:section_link_2) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_2)
    end
    fab!(:section_link_3) do
      Fabricate(:sidebar_section_link, sidebar_section: sidebar_section, linkable: sidebar_url_3)
    end

    it "sorts links" do
      serializer = SidebarSectionSerializer.new(sidebar_section, root: false).as_json
      expect(serializer[:links].map(&:id)).to eq(
        [sidebar_url_1.id, sidebar_url_2.id, sidebar_url_3.id],
      )

      sign_in(user)
      post "/sidebar_sections/reorder.json",
           params: {
             sidebar_section_id: sidebar_section.id,
             links_order: [sidebar_url_2.id, sidebar_url_3.id, sidebar_url_1.id],
           }

      serializer = SidebarSectionSerializer.new(sidebar_section.reload, root: false).as_json
      expect(serializer[:links].map(&:id)).to eq(
        [sidebar_url_2.id, sidebar_url_3.id, sidebar_url_1.id],
      )
    end

    it "is not allowed for not own sections" do
      sidebar_section_2 = Fabricate(:sidebar_section)
      post "/sidebar_sections/reorder.json",
           params: {
             sidebar_section_id: sidebar_section_2.id,
             links_order: [sidebar_url_2.id, sidebar_url_3.id, sidebar_url_1.id],
           }

      expect(response.status).to eq(403)

      serializer = SidebarSectionSerializer.new(sidebar_section, root: false).as_json
      expect(serializer[:links].map(&:id)).to eq(
        [sidebar_url_1.id, sidebar_url_2.id, sidebar_url_3.id],
      )
    end
  end

  describe "#destroy" do
    fab!(:sidebar_section) { Fabricate(:sidebar_section, user: user) }

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
  end
end
