# frozen_string_literal: true

RSpec.describe "Browse page" do
  fab!(:current_user, :user)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:browse_page) { PageObjects::Pages::ChatBrowse.new }

  before do
    sign_in(current_user)
    chat_system_bootstrap(current_user)
  end

  it "redirects to the homepage when public channels are disabled" do
    SiteSetting.enable_public_channels = false
    visit("/chat/browse")
    expect(page).to have_current_path("/latest")
  end

  it "redirects the archived tab to the default tab when archiving is disabled" do
    chat_page.visit_browse(:archived)
    expect(browse_page).to have_current_path("/chat/browse/open")
  end

  it "returns to the channels page on mobile", mobile: true do
    chat_page.visit_browse
    find(".c-navbar__back-button").click
    expect(browse_page).to have_current_path("/chat/channels")
  end

  context "when searching" do
    fab!(:foo) { Fabricate(:chat_channel, name: "foo") }
    fab!(:bar) { Fabricate(:chat_channel, name: "bar") }

    it "shows matching channels" do
      chat_page.visit_browse
      browse_page.search(foo.name)
      expect(browse_page).to have_channel(name: foo.name)
      expect(browse_page).to have_no_channel(name: bar.name)
    end

    it "shows the empty state instead of channels for an unmatched query" do
      chat_page.visit_browse
      expect(browse_page).to have_channel(name: foo.name)
      expect(browse_page).to have_channel(name: bar.name)

      browse_page.search("x")
      expect(browse_page).to have_channel(name: I18n.t("js.chat.empty_state.title"))
      expect(browse_page).to have_no_channel(name: foo.name)
      expect(browse_page).to have_no_channel(name: bar.name)
    end
  end

  context "when filtering by channel status" do
    fab!(:open_channel) { Fabricate(:chat_channel, status: :open) }
    fab!(:read_only_channel) { Fabricate(:chat_channel, status: :read_only) }
    fab!(:closed_channel) { Fabricate(:chat_channel, status: :closed) }
    fab!(:archived_channel) { Fabricate(:chat_channel, status: :archived) }
    fab!(:deleted_channel, :chat_channel)
    fab!(:dm) { Fabricate(:direct_message_channel, users: [current_user]) }

    before { deleted_channel.destroy! }

    def expect_only_channels(*visible)
      all = [open_channel, read_only_channel, closed_channel, archived_channel, deleted_channel]
      visible.each { |channel| expect(browse_page).to have_channel(name: channel.title) }
      (all - visible).each { |channel| expect(browse_page).to have_no_channel(name: channel.title) }
      expect(browse_page).to have_no_channel(name: dm.title(current_user))
    end

    it "filters the list as the user switches tabs" do
      chat_page.visit_browse
      expect(browse_page).to have_current_path("/chat/browse/open")
      expect(browse_page).to have_channel(name: I18n.t("js.chat.browse.filter_open"))
      expect(browse_page).to have_channel(name: I18n.t("js.chat.browse.filter_all"))
      expect(browse_page).to have_channel(name: I18n.t("js.chat.browse.filter_closed"))
      expect(browse_page).to have_no_channel(name: I18n.t("js.chat.browse.filter_archived"))
      expect_only_channels(open_channel)

      browse_page.change_status("all")
      expect_only_channels(open_channel, read_only_channel, closed_channel, archived_channel)

      browse_page.change_status("closed")
      expect_only_channels(closed_channel)
    end

    it "loads more channels when scrolling" do
      Fabricate.times(17, :chat_channel, chatable: open_channel.chatable)

      resize_window(height: 450) do
        chat_page.visit_browse(:all)
        expect(browse_page).to have_selector(".chat-channel-card", count: 10)

        scroll_to(find(".chat-channel-card:last-child"))
        expect(browse_page).to have_selector(".chat-channel-card", count: 20)

        scroll_to(find(".chat-channel-card:last-child"))
        expect(browse_page).to have_selector(".chat-channel-card", count: 21)
      end
    end

    it "shows the archived tab and its channels when archiving is enabled" do
      SiteSetting.chat_allow_archiving_channels = true
      chat_page.visit_browse(:archived)
      expect(browse_page).to have_channel(name: I18n.t("js.chat.browse.filter_archived"))
      expect_only_channels(archived_channel)
    end
  end
end
