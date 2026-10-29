# frozen_string_literal: true

RSpec.describe "Chat channel as the homepage" do
  fab!(:current_user, :user)
  fab!(:channel_1, :category_channel)
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    SiteSetting.top_menu = "latest|new|top|categories"
    SiteSetting.default_homepage = "chat"
    SiteSetting.chat_homepage_channel = channel_1.id
    sign_in(current_user)
  end

  it "renders the channel at the root path" do
    visit("/")

    expect(channel_page.messages).to have_message(id: message_1.id)
    expect(page).to have_current_path("/")
  end

  it "returns to the root path from the logo" do
    visit("/categories")
    find("#site-logo").click

    expect(channel_page.messages).to have_message(id: message_1.id)
    expect(page).to have_current_path("/")
  end

  it "keeps the channel's own path when visited directly" do
    visit(channel_1.relative_url)

    expect(channel_page.messages).to have_message(id: message_1.id)
    expect(page).to have_current_path(channel_1.relative_url)
  end

  it "shows the usual homepage when the user cannot chat" do
    SiteSetting.chat_allowed_groups = Fabricate(:group).id

    visit("/")

    # the fallback is still served at / like any other homepage
    expect(page).to have_css(".navigation-container .nav-item_latest.active")
    expect(page).to have_no_css(".chat-channel")
    expect(page).to have_current_path("/")
  end

  it "shows the usual homepage when the user has disabled chat" do
    current_user.user_option.update!(chat_enabled: false)

    visit("/")

    expect(page).to have_css(".navigation-container .nav-item_latest.active")
    expect(page).to have_no_css(".chat-channel")
    expect(page).to have_current_path("/")
  end

  it "leaves an individual homepage preference alone" do
    current_user.user_option.update!(homepage_id: UserOption::HOMEPAGES.key("categories"))

    visit("/")

    expect(page).to have_css(".navigation-container .nav-item_categories.active")
    expect(page).to have_no_css(".chat-channel")
  end

  context "when the site owner is onboarding" do
    fab!(:current_user, :admin)
    fab!(:other_channel, :category_channel)
    fab!(:other_message) { Fabricate(:chat_message, chat_channel: other_channel) }

    let(:banner) { PageObjects::Components::AdminOnboardingBanner.new }
    let(:sidebar) { PageObjects::Pages::ChatSidebar.new }

    before do
      SiteSetting.enable_site_owner_onboarding = true
      Theme.foundation_theme.set_default!
      channel_1.add(current_user)
      other_channel.add(current_user)
    end

    it "lets the owner see the checklist under the channel header on the Chat homepage but not another channel" do
      visit("/")

      expect(channel_page.messages).to have_message(id: message_1.id)
      expect(channel_page).to have_onboarding_banner_below_header
      expect_composer_in_viewport

      click_button(I18n.t("js.admin_onboarding_banner.collapse"), enable_aria_label: true)
      expect_composer_in_viewport

      visit(channel_1.relative_url)

      expect(channel_page.messages).to have_message(id: message_1.id)
      expect(channel_page).to have_onboarding_banner_below_header
      expect_composer_in_viewport

      sidebar.open_channel(other_channel)

      expect(channel_page.messages).to have_message(id: other_message.id)
      expect(banner).to be_not_visible
      expect_composer_in_viewport
    end

    it "lets the owner tick off chatting by sending a first message in the homepage channel" do
      visit("/")

      expect(banner).to have_step(
        "start_posting",
        title: I18n.t("js.chat.admin_onboarding.start_posting.title"),
        description:
          I18n.t("js.chat.admin_onboarding.start_posting.description", channel: channel_1.title),
      )
      expect(banner.step_not_completed?("start_posting")).to eq(true)

      banner.click_step_action("start_posting")
      expect(channel_page.composer).to be_focused

      channel_page.send_message("Hello everyone")

      expect(banner.step_completed?("start_posting")).to eq(true)
    end

    it "raises the checklist only once messages run beneath it" do
      visit("/")

      expect(channel_page).to have_onboarding_banner_below_header
      expect(channel_page).to have_no_elevated_overlays

      Fabricate.times(40, :chat_message, chat_channel: channel_1)
      page.refresh

      expect(channel_page).to have_onboarding_banner_below_header
      expect(channel_page).to have_elevated_overlays
    end

    it "keeps the pinned message bar and channel notices clear of the checklist" do
      SiteSetting.chat_pinned_messages = true
      Fabricate(
        :chat_pinned_message,
        chat_message: message_1,
        chat_channel: channel_1,
        user: current_user,
      )

      visit("/")

      expect(channel_page).to have_onboarding_banner_below_pinned_bar
      try_until_success { expect(channel_page).to have_notices_below_onboarding_banner }
    end

    def expect_composer_in_viewport
      try_until_success do
        bottom =
          channel_page.composer.component.evaluate_script("this.getBoundingClientRect().bottom")
        viewport_height = page.evaluate_script("window.innerHeight")
        expect(bottom).to be <= viewport_height
        expect(bottom).to be >= viewport_height - 20
      end
    end
  end

  context "when on mobile", mobile: true do
    it "links back to the forum rather than the homepage" do
      visit("/")
      expect(channel_page.messages).to have_message(id: message_1.id)

      chat_page.back_to_channels_list

      expect(page).to have_css(".back-to-forum[href='/latest']")
    end
  end

  context "when the user prefers the drawer" do
    it "still opens full page from the homepage" do
      visit("/categories")
      chat_page.prefers_drawer
      find("#site-logo").click

      expect(channel_page.messages).to have_message(id: message_1.id)
      expect(page).to have_current_path("/")
    end
  end
end
