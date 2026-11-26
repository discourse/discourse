# frozen_string_literal: true

RSpec.describe "Navigation" do
  fab!(:category)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:user, :admin)
  fab!(:category_channel)
  fab!(:category_channel_2, :category_channel)
  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:sidebar_page) { PageObjects::Pages::ChatSidebar.new }

  before do
    chat_system_bootstrap(user, [category_channel, category_channel_2])
    sign_in(user)
    SiteSetting.navigation_menu = "header dropdown"
  end

  it "uses chat (not core) sidebar" do
    visit("/chat")

    expect(page).to have_css(".channels-list")
    expect(page).to have_no_css("#d-sidebar")
  end

  context "when sidebar is enabled as the navigation menu" do
    before { SiteSetting.navigation_menu = "sidebar" }

    it "uses core sidebar" do
      visit("/chat")

      expect(page).to have_css("#d-sidebar")
      expect(page).to have_no_css(".channels-list")
    end

    context "when visiting on mobile", mobile: true do
      it "has no sidebar" do
        chat_page.visit_channel(category_channel_2)

        expect(page).to have_no_css("#d-sidebar")
      end
    end

    context "when channel titles and descriptions contain HTML-escapable characters" do
      fab!(:other_user) { Fabricate(:user, name: "Frodo's <b>friend</b>") }
      fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [user, other_user]) }
      fab!(:group_dm_channel) do
        Fabricate(
          :direct_message_channel,
          users: [user, other_user, Fabricate(:user)],
          name: "Frodo's <b>party</b>",
        )
      end

      before do
        SiteSetting.enable_names = true
        SiteSetting.display_name_on_posts = true
        SiteSetting.prioritize_username_in_ux = false
      end

      it "escapes titles and descriptions once" do
        category_channel.update!(description: "Frodo's <b>notes</b>")
        visit("/")

        dm_link =
          sidebar_page.dms_section.find(sidebar_page.channel_section_link_selector(dm_channel))
        expect(dm_link).to have_text("Frodo's <b>friend</b>", exact: true)
        expect(dm_link["title"]).to eq("Chat with Frodo's <b>friend</b>")

        group_dm_link =
          sidebar_page.dms_section.find(
            sidebar_page.channel_section_link_selector(group_dm_channel),
          )
        expect(group_dm_link["title"]).to eq("Chat in Frodo's <b>party</b>")

        channel_link =
          sidebar_page.channels_section.find(
            sidebar_page.channel_section_link_selector(category_channel),
          )
        expect(channel_link["title"]).to eq("Frodo's <b>notes</b>")

        dm_channel.membership_for(user).update!(starred: true)
        visit("/")

        starred_link =
          sidebar_page.starred_section.find(sidebar_page.channel_section_link_selector(dm_channel))
        expect(starred_link).to have_text("Frodo's <b>friend</b>", exact: true)
        expect(starred_link["title"]).to eq("Chat with Frodo's <b>friend</b>")
      end
    end

    context "when public channels are disabled" do
      before { SiteSetting.enable_public_channels = false }

      it "has public channels section" do
        visit("/")

        expect(sidebar_page).to have_no_public_channels_section
      end
    end
  end

  context "when visiting on mobile", mobile: true do
    it "has no sidebar" do
      chat_page.visit_channel(category_channel_2)

      expect(page).to have_no_css(".channels-list")
    end
  end
end
