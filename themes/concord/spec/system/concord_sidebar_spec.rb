# frozen_string_literal: true

RSpec.describe "Concord sidebar" do
  fab!(:admin)
  fab!(:group)
  fab!(:category) { Fabricate(:category, name: "Lounge") }
  fab!(:chat_channel) { Fabricate(:category_channel, chatable: category, name: "hangout") }
  fab!(:voice_room) { Fabricate(:live_room, name: "Campfire", public: true, creator: admin) }

  fab!(:theme) do
    SystemThemesManager.sync_theme!("concord")
    Theme.concord_theme
  end
  let(:sidebar) { find(".sidebar-wrapper") }
  let(:modal) { PageObjects::Modals::Base.new }
  let(:form) { PageObjects::Components::FormKit.new(".concord-create-channel-modal form") }

  before do
    theme.set_default!
    SiteSetting.navigation_menu = "sidebar"
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
    SiteSetting.live_create_room_allowed_groups = Group::AUTO_GROUPS[:admins]
    chat_system_bootstrap(admin, [chat_channel])
    group.add(admin)
    sign_in(admin)
  end

  def screenshot(name)
    dir = ENV["DCCK_SCREENSHOTS"]
    page.save_screenshot(File.join(dir, "#{name}.png")) if dir # rubocop:disable Lint/Debugger
  end

  # Whether the current channel's row is inside its list's scrolled view, and
  # not under the list's sticky server name.
  def row_in_view?(list)
    page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelector("#{list} .sidebar-section-link.active").getBoundingClientRect();
        let scroller = document.querySelector("#{list} .sidebar-section-link.active").parentElement;
        while (!["auto", "scroll"].includes(getComputedStyle(scroller).overflowY)) {
          scroller = scroller.parentElement;
        }
        const view = scroller.getBoundingClientRect();
        const header = document.querySelector("#{list} .concord-server-header");
        const covered = header && getComputedStyle(header).position === "sticky" ? header.offsetHeight : 0;
        return scroller.scrollTop > 0 && row.top >= view.top + covered && row.bottom <= view.bottom;
      })()
    JS
  end

  def channel_link(name)
    sidebar.find(".sidebar-section-link[data-link-name='#{name}']")
  end

  # The create and privacy modals keep their buttons in the modal's footer.
  def submit_modal
    find(".d-modal__footer .btn-primary").click
  end

  def open_create_modal
    find(".concord-server-header__create").click
    expect(modal).to be_open
  end

  def group_chooser
    PageObjects::Components::SelectKit.new(".form-kit__field[data-name='groupIds'] .select-kit")
  end

  def section_chooser
    PageObjects::Components::SelectKit.new(".form-kit__field[data-name='section'] .select-kit")
  end

  it "replaces the sidebar with one list of channels, on forum and chat pages" do
    visit("/latest")

    expect(page).to have_css(".concord-server-header")
    expect(channel_link("forum-#{category.slug}")).to be_present
    expect(channel_link("text-hangout")).to be_present
    expect(channel_link("live-room-#{voice_room.id}")).to be_present
    expect(sidebar).to have_no_css(".sidebar-section[data-section-name='community']")
    expect(sidebar).to have_no_css(".sidebar-section[data-section-name='categories']")

    channel_link("text-hangout").click
    expect(page).to have_current_path(%r{/chat/c/hangout/#{chat_channel.id}})
    expect(page).to have_no_css(".chat-drawer.is-expanded")
    expect(channel_link("forum-#{category.slug}")).to be_present
    expect(sidebar).to have_no_css(".sidebar-section[data-section-name='chat-channels']")
  end

  it "shows the sidebar when the site's navigation menu is the header dropdown" do
    SiteSetting.navigation_menu = "header dropdown"
    visit("/latest")

    expect(page).to have_css(".concord-server-header")
    expect(channel_link("forum-#{category.slug}")).to be_present
  end

  it "lists channels outside a section together, alphabetically" do
    visit("/latest")

    top = sidebar.find(".sidebar-section[data-section-name='concord-channels']")
    expect(top).to have_css(".sidebar-section-link", count: 4)
    expect(top.all(".sidebar-section-link-content-text").map(&:text)).to eq(
      %w[Campfire hangout Lounge Uncategorized],
    )
  end

  it "lists a forum channel's subcategories above its topics, as boxes" do
    Fabricate(:category, name: "Annex", parent_category: category)
    category.update!(show_subcategory_list: false, subcategory_list_style: "rows")

    visit("/c/#{category.slug}/#{category.id}")
    expect(find("#main-outlet")).to have_css(".category-boxes .category-box", text: "Annex")

    visit("/latest")
    sidebar.find(".sidebar-section-link", text: "Lounge").click
    expect(page).to have_current_path(%r{/c/#{category.slug}/#{category.id}})
    expect(find("#main-outlet")).to have_css(".category-boxes .category-box", text: "Annex")
  end

  it "keeps channels with long names to the same width" do
    Fabricate(:category, name: "A really quite remarkably long channel name")
    visit("/latest")

    widths = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".concord-channel")].map((link) => link.getBoundingClientRect().width)
    JS
    expect(widths.uniq.size).to eq(1)
  end

  it "creates a private forum channel limited to the chosen groups" do
    visit("/latest")
    open_create_modal

    form.field("type").select("forum")
    form.field("name").fill_in("secret-plans")
    form.field("isPrivate").toggle
    group_chooser.expand
    group_chooser.search(group.name)
    group_chooser.select_row_by_name(group.name)
    group_chooser.collapse
    screenshot("create-modal")
    submit_modal

    expect(page).to have_current_path(%r{/c/secret-plans/\d+})
    created = Category.find_by(name: "secret-plans")
    expect(created.read_restricted).to eq(true)
    expect(created.category_groups.pluck(:group_id)).to contain_exactly(group.id)
    expect(channel_link("forum-secret-plans")).to be_present
  end

  it "creates a text channel in a new section typed into the section picker" do
    visit("/latest")
    open_create_modal

    form.field("type").select("text")
    section_chooser.expand
    section_chooser.search("Gaming")
    section_chooser.select_row_by_value("Gaming")
    screenshot("new-section-picked")
    expect(page).to have_css(
      ".form-kit__field[data-name='section'] .select-kit-header .name",
      text: "Gaming",
    )
    form.field("name").fill_in("lfg")
    submit_modal

    expect(page).to have_current_path(%r{/chat/c/lfg/\d+})
    created = Chat::Channel.find_by(name: "lfg")
    expect(created.chatable.parent_category.slug).to eq("chat-channels")

    # Posting in the channel only needs Reply, so nobody else can start topics
    # in its category, and the container can only be seen.
    expect(created.chatable.category_groups.pluck(:group_id, :permission_type)).to eq(
      [[Group::AUTO_GROUPS[:everyone], CategoryGroup.permission_types[:create_post]]],
    )
    expect(created.chatable.topic.closed).to eq(true)
    expect(created.chatable.parent_category.category_groups.pluck(:permission_type)).to eq(
      [CategoryGroup.permission_types[:readonly]],
    )

    sections = theme.reload.settings[:sidebar_sections].value
    expect(sections).to eq(
      [{ "name" => "Gaming", "channels" => [{ "type" => "text", "id" => created.id }] }],
    )

    gaming = sidebar.find(".sidebar-section[data-section-name='concord-section-gaming']")
    expect(gaming).to have_css(".sidebar-section-link[data-link-name='text-lfg']")
    expect(sidebar).to have_no_css(
      ".sidebar-section-link[data-link-name='forum-chat-channels/#{created.chatable.slug}']",
    )

    # Deleting it takes the category that only existed to back it.
    link = channel_link("text-lfg")
    link.hover
    link.find(".sidebar-section-hover-button").click
    find(".concord-action-menu .btn", text: "Delete").click
    find(".dialog-footer .btn-danger").click
    expect(page).to have_no_css(".sidebar-section-link[data-link-name='text-lfg']")
    # It moves on to the latest page once everything's deleted.
    expect(page).to have_current_path("/latest")
    expect(Category.exists?(created.chatable_id)).to eq(false)
  end

  it "leaves deleting a channel with a backing category to its menu" do
    container = Fabricate(:category, name: "Chat channels", slug: "chat-channels")
    backing = Fabricate(:category, name: "plans", parent_category: container)
    channel = Fabricate(:category_channel, chatable: backing, name: "plans")
    channel.add(admin)

    visit("/chat/c/#{channel.slug}/#{channel.id}/info/settings")
    expect(page).to have_css(".c-channel-settings .close-btn")
    expect(page).to have_css(".c-channel-settings .delete-btn", visible: :hidden)
    expect(page).to have_no_css(".c-channel-settings .delete-btn")

    # A channel on a category of its own keeps chat's delete.
    visit("/chat/c/#{chat_channel.slug}/#{chat_channel.id}/info/settings")
    expect(page).to have_css(".c-channel-settings .delete-btn")
  end

  it "opens chat full page even when the drawer was preferred" do
    visit("/latest")
    page.execute_script(
      "localStorage.setItem('discourse_chat_preferred_mode', JSON.stringify('DRAWER_CHAT'))",
    )
    visit("/latest")

    channel_link("text-hangout").click
    expect(page).to have_current_path(%r{/chat/c/hangout/#{chat_channel.id}})
    expect(page).to have_no_css(".chat-drawer.is-expanded")
    expect(page).to have_no_css(".c-navbar__open-drawer-button", visible: :visible)

    # Chat's drawer shortcut switches to the drawer just before it navigates.
    visit("/c/#{category.slug}/#{category.id}")
    expect(page).to have_css(".concord-channel-header__name", text: "Lounge")
    find("body").send_keys("-")
    expect(page).to have_current_path(%r{/chat/c/})
    expect(page).to have_no_css(".chat-drawer.is-expanded")
  end

  it "creates a public voice channel" do
    visit("/latest")
    open_create_modal

    form.field("type").select("voice")
    form.field("name").fill_in("Late night")
    submit_modal

    room = Live::Room.find_by(name: "Late night")
    expect(room.public).to eq(true)
    expect(channel_link("live-room-#{room.id}")).to be_present
  end

  it "mutes a text channel and moves it to a section from its menu" do
    theme.update_setting(:sidebar_sections, [{ "name" => "Hangouts", "channels" => [] }].to_json)
    theme.save!

    visit("/latest")

    link = channel_link("text-hangout")
    link.hover
    link.find(".sidebar-section-hover-button").click
    labels = all(".concord-action-menu .btn").map(&:text)
    expect(labels.first(4)).to eq(["Mark as read", "Rename", "Privacy", "Copy link"])
    expect(labels.last).to eq("Delete")
    expect(labels).not_to include("Hangouts")
    screenshot("channel-menu")
    labels_left = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".concord-action-menu .btn .d-button-label")].map((l) => Math.round(l.getBoundingClientRect().left))
    JS
    expect(labels_left.uniq.size).to eq(1)
    find(".concord-action-menu .btn", text: "Mute").click

    expect(sidebar).to have_css(".sidebar-section-link--muted[data-link-name='text-hangout']")
    expect(chat_channel.membership_for(admin).reload.muted).to eq(true)

    link = channel_link("text-hangout")
    link.hover
    link.find(".sidebar-section-hover-button").click
    find(".concord-action-menu [data-item-id='move-to-section']").click
    # Beside the channel's menu, which stays open.
    expect(page).to have_css(".concord-action-menu", count: 2)
    screenshot("channel-submenu")
    find(".concord-action-menu .btn", text: "Hangouts").click
    expect(page).to have_no_css(".concord-action-menu")

    hangouts = sidebar.find(".sidebar-section[data-section-name='concord-section-hangouts']")
    expect(hangouts).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
  end

  it "moves a channel into a new section from its menu" do
    visit("/latest")

    link = channel_link("text-hangout")
    link.hover
    link.find(".sidebar-section-hover-button").click
    find(".concord-action-menu [data-item-id='move-to-section']").click
    find(".concord-action-menu .btn", text: "New section…").click

    name_form = PageObjects::Components::FormKit.new(".concord-rename-modal form")
    name_form.field("name").fill_in("Hangouts")
    name_form.submit

    hangouts = sidebar.find(".sidebar-section[data-section-name='concord-section-hangouts']")
    expect(hangouts).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
    expect(theme.reload.settings[:sidebar_sections].value).to eq(
      [{ "name" => "Hangouts", "channels" => [{ "type" => "text", "id" => chat_channel.id }] }],
    )
  end

  it "scrolls the current channel into view in the sidebar" do
    campsites = 40.times.map { |i| Fabricate(:category, name: "Campsite #{i.to_s.rjust(2, "0")}") }
    resize_window(height: 600) do
      visit(campsites.last.url)
      expect(page).to have_css(".sidebar-wrapper .sidebar-section-link.active")
      expect(row_in_view?(".sidebar-wrapper")).to eq(true)

      # And when arriving from outside the list.
      page.execute_script(<<~JS)
        document.querySelectorAll(".sidebar-wrapper *").forEach((el) => (el.scrollTop = 0));
      JS
      expect(row_in_view?(".sidebar-wrapper")).to eq(false)
      page.execute_script("Discourse.visit(arguments[0])", campsites[30].url)
      expect(page).to have_css(
        ".sidebar-wrapper .sidebar-section-link.active[data-link-name='forum-#{campsites[30].slug}']",
      )
      try_until_success { expect(row_in_view?(".sidebar-wrapper")).to eq(true) }
    end
  end

  describe "text channels someone hasn't joined" do
    fab!(:newcomer) { Fabricate(:user, trust_level: TrustLevel[0]) }
    fab!(:porch) { Fabricate(:category_channel, chatable: category, name: "porch") }
    fab!(:secret_category) { Fabricate(:private_category, group:, name: "Secret") }
    fab!(:secret) { Fabricate(:category_channel, chatable: secret_category, name: "secret-plans") }

    before do
      SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
      porch.add(newcomer)
      porch.membership_for(newcomer).update!(following: false)
      sign_in(newcomer)
    end

    it "can post in a channel whose category only lets them reply" do
      container = Fabricate(:category, slug: "chat-channels")
      container.set_permissions(everyone: :readonly)
      container.save!
      backing = Fabricate(:category, name: "lfg", parent_category: container)
      backing.set_permissions(everyone: :create_post)
      backing.save!
      lfg = Fabricate(:category_channel, chatable: backing, name: "lfg")
      visit("/latest")

      channel_link("text-lfg").click
      find(".chat-composer__input").fill_in(with: "anyone up for a game?")
      find(".chat-composer__input").send_keys(:enter)

      expect(page).to have_css(".chat-message-text", text: "anyone up for a game?")
      try_until_success { expect(lfg.chat_messages.last&.message).to eq("anyone up for a game?") }
    end

    it "lists every channel they can see, and joins one when it's opened" do
      visit("/latest")

      expect(channel_link("text-hangout")).to be_present
      expect(channel_link("text-porch")).to be_present
      expect(sidebar).to have_no_css(".sidebar-section-link[data-link-name='text-secret-plans']")
      expect(chat_channel.membership_for(newcomer)).to be_nil

      channel_link("text-hangout").click
      expect(page).to have_css(".chat-channel[data-id='#{chat_channel.id}']")
      expect(page).to have_css(".chat-composer__input")
      try_until_success { expect(chat_channel.membership_for(newcomer)&.following).to eq(true) }

      channel_link("text-porch").click
      expect(page).to have_css(".chat-channel[data-id='#{porch.id}']")
      try_until_success { expect(porch.membership_for(newcomer).reload.following).to eq(true) }
      expect(channel_link("text-hangout")).to be_present
    end
  end

  describe "voice channels" do
    fab!(:camper) { Fabricate(:user, username: "camper", name: "Cam Per") }

    before { Live::ParticipantTracker.add(voice_room.id, camper.id) }

    it "lists who's in the call under the channel, and has no member list" do
      visit("/latest")

      room_link = channel_link("live-room-#{voice_room.id}")
      expect(room_link).to have_no_css(".sidebar-section-link-content-badge")
      participant =
        sidebar.find(
          ".sidebar-section-link.live-sidebar-participant[data-link-name='live-participant-#{voice_room.id}-#{camper.id}']",
        )
      expect(participant).to have_css(".sidebar-section-link-prefix img")
      expect(participant).to have_css(".live-participant-suffix", visible: :all)
      names = page.evaluate_script(<<~JS)
        [...document.querySelectorAll(".sidebar-section-link")].map((link) => link.dataset.linkName)
      JS
      expect(names[names.index("live-room-#{voice_room.id}") + 1]).to eq(
        "live-participant-#{voice_room.id}-#{camper.id}",
      )
      screenshot("voice-participants")

      visit("/live/r/#{voice_room.slug}")
      expect(page).to have_css(".concord-channel-header__name", text: "Campfire")
      expect(page).to have_no_css(".concord-channel-header [data-action-id='member-list']")
      expect(page).to have_no_css(".concord-member-list")
      expect(page).to have_no_css("body.concord-member-list-open")
    end
  end

  describe "AI conversations link" do
    fab!(:llm_model)

    before do
      SiteSetting.discourse_ai_enabled = true
      SiteSetting.ai_bot_enabled = true
      SiteSetting.ai_bot_enabled_llms = llm_model.id.to_s
      AiAgent.ensure_users!
    end

    it "shows the AI conversations beside the DM button, without leaving the page" do
      visit("/latest")

      link = find(".concord-server-header__ai")
      next_to_dms = page.evaluate_script(<<~JS)
        document.querySelector(".sidebar-wrapper .concord-server-header__ai").nextElementSibling.matches(".concord-server-header__dms")
      JS
      expect(next_to_dms).to eq(true)
      sizes = page.evaluate_script(<<~JS)
        ["ai", "dms", "create"].map((name) => {
          const rect = document.querySelector(`.sidebar-wrapper .concord-server-header__${name}`).getBoundingClientRect();
          return [Math.round(rect.width), Math.round(rect.height)];
        })
      JS
      expect(sizes.uniq.size).to eq(1)
      screenshot("ai-conversations-link")

      # A toggle, like the DM button: the list swaps, the page stays.
      link.click
      expect(page).to have_css(".concord-server-header__ai.--active[aria-pressed='true']")
      expect(sidebar).to have_css(".ai-new-question-button")
      expect(page).to have_no_css(".concord-channel--forum")
      expect(page).to have_current_path("/latest")
      screenshot("ai-conversations-active")

      find(".concord-server-header__ai").click
      expect(page).to have_css(".concord-server-header__ai[aria-pressed='false']")
      expect(channel_link("forum-#{category.slug}")).to be_present
      expect(page).to have_current_path("/latest")

      # Its way back does the same.
      find(".concord-server-header__ai").click
      sidebar.find(".sidebar-sections__back-to-forum", text: "Back to all channels").click
      expect(channel_link("forum-#{category.slug}")).to be_present
      expect(page).to have_current_path("/latest")
      expect(page).to have_no_css("body.has-ai-conversations-sidebar")

      # Starting a conversation goes to Discourse AI's page, list and all.
      find(".concord-server-header__ai").click
      sidebar.find(".ai-new-question-button").click
      expect(page).to have_current_path(%r{^/discourse-ai/ai-bot/conversations})
      expect(page).to have_css(".concord-server-header__ai[aria-pressed='true']")
    end

    it "opens the conversations on its own pages" do
      visit("/discourse-ai/ai-bot/conversations")
      expect(page).to have_css(".concord-server-header__ai[aria-pressed='true']")
    end

    it "is never pressed at the same time as the DM button" do
      visit("/latest")
      find(".concord-server-header__dms").click
      expect(page).to have_css(".concord-server-header__dms[aria-pressed='true']")

      find(".concord-server-header__ai").click
      expect(page).to have_css(".concord-server-header__ai[aria-pressed='true']")
      expect(page).to have_css(".concord-server-header__dms[aria-pressed='false']")
      expect(sidebar).to have_css(".sidebar-sections__back-to-forum", text: "Back to all channels")

      # From the conversations, the DM button shows the DMs, laid out as they
      # are from the channels.
      find(".concord-server-header__dms").click
      back = sidebar.find(".concord-dm-header__back", text: "Back to all channels")
      expect(back.evaluate_script("getComputedStyle(this).paddingTop")).to eq("0px")
      expect(page).to have_css(".concord-server-header__dms[aria-pressed='true']")
      expect(page).to have_css(".concord-server-header__ai[aria-pressed='false']")
    end

    it "can be turned off" do
      theme.update_setting(:ai_conversations_link, false)
      theme.save!
      visit("/latest")

      expect(page).to have_css(".concord-server-header__dms")
      expect(page).to have_no_css(".concord-server-header__ai")
    end
  end

  describe "coming back" do
    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    it "reopens the last channel on the site's address" do
      visit("/chat/c/#{chat_channel.slug}/#{chat_channel.id}")
      expect(page).to have_css(".chat-channel[data-id='#{chat_channel.id}']")

      visit("/")
      expect(page).to have_current_path(%r{\A/chat/c/[^/]+/#{chat_channel.id}})
      expect(page).to have_css(".chat-channel[data-id='#{chat_channel.id}']")
    end

    it "reopens a topic's channel" do
      visit(topic.relative_url)
      expect(page).to have_css("#topic-title")
      visit("/")

      expect(page).to have_current_path(category.relative_url)
    end

    it "leaves links to other pages alone" do
      visit("/chat/c/#{chat_channel.slug}/#{chat_channel.id}")
      expect(page).to have_css(".chat-channel[data-id='#{chat_channel.id}']")

      visit("/latest")
      expect(page).to have_css(".topic-list")
      expect(page).to have_current_path("/latest")
    end

    it "falls back to the homepage when the channel's gone" do
      visit("/chat/c/#{chat_channel.slug}/#{chat_channel.id}")
      expect(page).to have_css(".chat-channel[data-id='#{chat_channel.id}']")
      chat_channel.trash!

      visit("/")
      expect(page).to have_css(".topic-list")
      expect(page).to have_current_path("/")
      expect(
        page.evaluate_script(
          "String(localStorage.getItem('discourse_concord-last-channel:#{admin.id}'))",
        ),
      ).to eq("null")
    end

    it "falls back to the homepage when a tag channel's gone" do
      tag = Fabricate(:tag, name: "campfire-songs")
      visit("/tag/#{tag.name}")
      expect(page).to have_css(".concord-channel-header")
      tag.destroy!

      visit("/")
      expect(page).to have_css(".topic-list")
      expect(page).to have_current_path("/")
    end

    it "can be turned off" do
      theme.update_setting(:remember_last_channel, false)
      theme.save!
      visit(category.relative_url)
      expect(page).to have_css(".topic-list")

      visit("/")
      expect(page).to have_css(".topic-list")
      expect(page).to have_current_path("/")
    end
  end

  it "labels the admin sidebar's way back for the channels" do
    visit("/admin")
    expect(sidebar).to have_css(".sidebar-sections__back-to-forum", text: "Back to all channels")
  end

  describe "privacy" do
    let(:privacy_form) do
      PageObjects::Components::FormKit.new(".concord-channel-privacy-modal form")
    end

    def open_privacy(name)
      link = channel_link(name)
      link.hover
      link.find(".sidebar-section-hover-button").click
      find(".concord-action-menu [data-item-id='privacy']").click
    end

    it "makes a forum channel private, and public again" do
      visit("/latest")

      open_privacy("forum-lounge")
      expect(privacy_form.field("isPrivate")).to have_value(false)
      privacy_form.field("isPrivate").toggle
      group_chooser.expand
      group_chooser.search(group.name)
      group_chooser.select_row_by_name(group.name)
      group_chooser.collapse
      screenshot("privacy")
      submit_modal

      expect(page).to have_no_css(".concord-channel-privacy-modal")
      expect(category.reload.read_restricted).to eq(true)
      expect(category.category_groups.pluck(:group_id)).to contain_exactly(group.id)

      open_privacy("forum-lounge")
      expect(privacy_form.field("isPrivate")).to have_value(true)
      privacy_form.field("isPrivate").toggle
      submit_modal

      expect(page).to have_no_css(".concord-channel-privacy-modal")
      expect(category.reload.read_restricted).to eq(false)
    end

    it "keeps the groups a forum's subcategories use" do
      designers = Fabricate(:group, name: "designers")
      Fabricate(:private_category, group: designers, parent_category: category, name: "Mockups")
      visit("/latest")

      open_privacy("forum-lounge")
      privacy_form.field("isPrivate").toggle
      expect(page).to have_css(".concord-channel-privacy-modal", text: "designers")
      submit_modal

      expect(page).to have_no_css(".concord-channel-privacy-modal")
      expect(category.reload.read_restricted).to eq(true)
      expect(category.category_groups.pluck(:group_id)).to contain_exactly(designers.id)
    end

    it "can't make a forum private while a subcategory is public" do
      Fabricate(:category, parent_category: category, name: "Campfire stories")
      visit("/latest")

      open_privacy("forum-lounge")
      expect(page).to have_css(
        ".form-kit__field[data-name='isPrivate'] button[role='switch'][disabled]",
        visible: :all,
      )
      expect(page).to have_css(".concord-channel-privacy-modal", text: "Campfire stories")
    end

    it "explains what a private parent allows a subcategory" do
      parent = Fabricate(:private_category, group: Group[:staff], name: "Private events")
      design =
        Fabricate(:private_category, group: Group[:staff], parent_category: parent, name: "Design")
      visit("/c/#{parent.slug}/#{design.slug}/#{design.id}")

      open_privacy("forum-#{parent.slug}/#{design.slug}")
      modal = find(".concord-channel-privacy-modal")
      expect(modal).to have_text(
        "Stays private, since its Private events parent category is private.",
      )
      expect(modal).to have_text("Only groups that can see Private events can be added: staff.")
      expect(page).to have_css(
        ".form-kit__field[data-name='isPrivate'] button[role='switch'][disabled]",
        visible: :all,
      )
      screenshot("privacy-private-parent")

      modal.first(".concord-channel-privacy-modal__parent", text: "Private events").click
      expect(page).to have_current_path(%r{/c/#{parent.slug}/edit/security})
      expect(page).to have_no_css(".concord-channel-privacy-modal")
    end

    it "makes a text channel private through the category backing it" do
      container = Fabricate(:category, name: "Chat channels", slug: "chat-channels")
      backing = Fabricate(:category, name: "plans", parent_category: container)
      channel = Fabricate(:category_channel, chatable: backing, name: "plans")
      channel.add(admin)
      visit("/latest")

      open_privacy("text-plans")
      privacy_form.field("isPrivate").toggle
      group_chooser.expand
      group_chooser.search(group.name)
      group_chooser.select_row_by_name(group.name)
      group_chooser.collapse
      submit_modal

      expect(page).to have_no_css(".concord-channel-privacy-modal")
      expect(backing.reload.read_restricted).to eq(true)
      expect(backing.category_groups.pluck(:group_id, :permission_type)).to contain_exactly(
        [group.id, CategoryGroup.permission_types[:create_post]],
      )
      expect(container.reload.read_restricted).to eq(false)
    end

    it "points a chat channel on a shared category at that category" do
      visit("/latest")

      open_privacy("text-hangout")
      expect(page).to have_css(".concord-channel-privacy-modal__shared", text: "Lounge")
      find(".concord-channel-privacy-modal .btn", text: "Open category security").click
      expect(page).to have_current_path(%r{/c/#{category.slug}/edit/security})
    end

    it "makes a voice channel private" do
      visit("/latest")

      open_privacy("live-room-#{voice_room.id}")
      privacy_form.field("isPrivate").toggle
      submit_modal

      expect(page).to have_no_css(".concord-channel-privacy-modal")
      expect(voice_room.reload.public).to eq(false)
    end
  end

  it "renames a section from its heading menu" do
    theme.update_setting(:sidebar_sections, [{ "name" => "Old", "channels" => [] }].to_json)
    theme.save!

    visit("/latest")

    heading = sidebar.find(".sidebar-section[data-section-name='concord-section-old']")
    heading.find(".sidebar-section-header-wrapper").hover
    heading.find("[data-sidebar-action-id='sectionMenu']").click
    find(".concord-action-menu .btn", text: "Rename section").click

    rename_form = PageObjects::Components::FormKit.new(".concord-rename-modal form")
    rename_form.field("name").fill_in("New")
    rename_form.submit

    expect(sidebar).to have_css(".sidebar-section[data-section-name='concord-section-new']")
    expect(theme.reload.settings[:sidebar_sections].value.first["name"]).to eq("New")
  end

  it "centres section carets over the channel icons" do
    theme.update_setting(
      :sidebar_sections,
      [
        { "name" => "Hangouts", "channels" => [{ "type" => "forum", "id" => category.id }] },
      ].to_json,
    )
    theme.save!

    visit("/latest")

    section = "[data-section-name='concord-section-hangouts']"
    expect(sidebar).to have_css("#{section} .sidebar-section-link-prefix")
    screenshot("section")

    centres = page.evaluate_script(<<~JS)
      (() => {
        const centre = (selector) => {
          const rect = document.querySelector(selector).getBoundingClientRect();
          return rect.left + rect.width / 2;
        };
        return [
          centre("#{section} .sidebar-section-header-caret"),
          centre("#{section} .sidebar-section-link-prefix .prefix-icon"),
        ];
      })()
    JS
    expect(centres.first).to be_within(1).of(centres.last)
  end

  describe "direct messages" do
    fab!(:friend) { Fabricate(:user, username: "campmate") }
    fab!(:dm_channel) { Fabricate(:direct_message_channel, users: [admin, friend]) }

    let(:dms_button) { find(".concord-channel-header .concord-server-header__dms") }

    it "swaps the channel list for DMs from beside the server name" do
      Fabricate(:chat_message, chat_channel: dm_channel, user: friend, message: "hi there")
      visit("/latest")

      expect(dms_button).to have_css(".concord-server-header__dms-badge", text: "1")
      dms_button.click

      dms = sidebar.find(".sidebar-section[data-section-name='concord-dms']")
      expect(dms).to have_no_css(".sidebar-section-header")
      expect(dms).to have_css(".sidebar-section-link[data-link-name='dm-#{dm_channel.id}']")
      expect(sidebar).to have_no_css(".sidebar-section-link[data-link-name='text-hangout']")
      screenshot("dms")

      dms.find(".sidebar-section-link[data-link-name='dm-#{dm_channel.id}']").click
      expect(page).to have_current_path(%r{/chat/c/.+/#{dm_channel.id}})
      expect(sidebar).to have_css("[data-section-name='concord-dms']")
      screenshot("dm-channel")

      sidebar.find(".concord-dm-header__new.btn-default", text: "New DM or group chat").click
      expect(page).to have_css(".chat-modal-new-message")
      send_keys(:escape)

      find(".concord-channel-header .concord-server-header__dms").click
      expect(sidebar).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
      expect(sidebar).to have_no_css("[data-section-name='concord-dms']")
      expect(sidebar).to have_no_css(".concord-dm-header")
    end

    it "keeps the DMs showing while a new DM is started from a channel" do
      visit(category.relative_url)
      dms_button.click

      sidebar.find(".concord-dm-header__new").click
      expect(page).to have_css(".chat-modal-new-message")
      expect(sidebar).to have_css(".concord-dm-header")
      expect(sidebar).to have_css("[data-section-name='concord-dms']")
    end

    it "goes back to the channels from the top of the DMs" do
      visit("/latest")
      dms_button.click

      expect(sidebar.find(".concord-dm-header")).to have_css(
        ".concord-dm-header__back + .concord-dm-header__new",
      )
      sidebar.find(".concord-dm-header__back", text: "Back to all channels").click
      expect(sidebar).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
      expect(dms_button["aria-pressed"]).to eq("false")
    end

    it "closes a DM from its menu" do
      visit("/latest")
      dms_button.click

      row = sidebar.find(".sidebar-section-link[data-link-name='dm-#{dm_channel.id}']")
      row.hover
      row.find(".sidebar-section-hover-button").click
      menu = find(".concord-action-menu")
      expect(menu).to have_css("[data-item-id='mark-read']")
      expect(menu).to have_css(".btn", text: "Mute")
      expect(menu).to have_no_css("[data-item-id='move-to-section']")
      screenshot("dm-menu")

      menu.find("[data-item-id='close-dm']").click
      expect(sidebar).to have_no_css(".sidebar-section-link[data-link-name='dm-#{dm_channel.id}']")
      expect(dm_channel.membership_for(admin).reload.following).to eq(false)
    end

    it "follows the page between DMs and the server's channels" do
      visit("/chat/c/-/#{dm_channel.id}")
      expect(sidebar).to have_css(".sidebar-section-link[data-link-name='dm-#{dm_channel.id}']")
      expect(dms_button["aria-pressed"]).to eq("true")

      visit("/c/#{category.slug}/#{category.id}")
      expect(sidebar).to have_css(".sidebar-section-link[data-link-name='text-hangout']")
      expect(sidebar).to have_no_css("[data-section-name='concord-dms']")
    end
  end

  describe "header" do
    let(:header) { find(".concord-channel-header") }

    it "opens the site's pages from the server name" do
      Fabricate(:reviewable)
      visit("/latest")

      expect(header).to have_css(".concord-server-header__review-badge", text: "1")
      expect(page.evaluate_script(<<~JS)).to eq("absolute")
        getComputedStyle(document.querySelector(".concord-server-header__review-badge")).position
      JS
      header.find(".concord-server-header__name").click
      menu = find(".concord-action-menu")
      expect(menu).to have_css("[data-item-id='admin']")
      expect(menu).to have_css("[data-item-id='review'] .concord-action-menu__badge")
      expect(menu).to have_css("[data-item-id='keyboard-shortcuts']")
      screenshot("server-menu")

      menu.find("[data-item-id='about']").click
      expect(page).to have_current_path("/about")
    end

    it "titles the server menu's pages" do
      SiteSetting.enable_badges = true
      SiteSetting.enable_group_directory = true
      badge = Badge.find(Badge::FirstLike)

      {
        "/about" => "About",
        "/g" => "Groups",
        "/g/#{group.name}" => group.name,
        "/u" => "Users",
        "/badges" => "Badges",
        "/badges/#{badge.id}/#{badge.slug}" => badge.display_name,
        "/review" => "Review",
        "/admin" => "Admin",
      }.each do |path, title|
        visit(path)
        expect(header).to have_css(".concord-channel-header__name", exact_text: title)
        expect(page).to have_no_css(
          ".badges > h1, .show-badge > h1, .group-info-names .group-info-details",
          visible: :visible,
        )
        screenshot("page#{path.tr("/", "-")}")
      end
    end

    it "replaces core's header and chat's channel bar with the channel's own" do
      visit("/chat/c/hangout/#{chat_channel.id}")

      expect(page).to have_no_css(".d-header > .wrap", visible: :visible)
      expect(header).to have_css(".concord-channel-header__name", text: "hangout")
      expect(page).to have_css(".c-routes.--channel")
      expect(page).to have_no_css(".c-routes.--channel > .c-navbar-container", visible: :visible)

      gap = page.evaluate_script(<<~JS)
        window.innerHeight - document.querySelector(".chat-channel").getBoundingClientRect().bottom
      JS
      expect(gap).to be_within(2).of(0)
      screenshot("chat")

      header.find("[data-action-id='pins']").click
      expect(page).to have_current_path(%r{/chat/c/hangout/#{chat_channel.id}/pins})
    end

    it "searches from a dropdown without widening the page" do
      visit("/latest")

      overflow =
        page.evaluate_script(
          "document.documentElement.scrollWidth - document.documentElement.clientWidth",
        )
      expect(overflow).to eq(0)

      header.find(".concord-channel-header__search").click
      expect(page).to have_css(".concord-search-panel #concord-search-input:focus")
      expect(page.evaluate_script(<<~JS)).to eq(550)
        document.querySelector(".concord-search-panel").getBoundingClientRect().width
      JS
      screenshot("search")

      send_keys(:escape)
      expect(page).to have_no_css(".concord-search-panel")
    end

    # Not on the latest page, where / goes to the welcome banner's search.
    it "opens search from its keyboard shortcut" do
      visit("/c/#{category.slug}/#{category.id}")
      expect(header).to have_css(".concord-channel-header__name", text: "Lounge")

      find("body").send_keys("/")
      expect(page).to have_css(".concord-search-panel #concord-search-input:focus")
      send_keys(:escape)
      expect(page).to have_no_css(".concord-search-panel")
    end

    it "opens the user menu from its keyboard shortcut" do
      visit("/c/#{category.slug}/#{category.id}")
      expect(header).to have_css(".concord-channel-header__name", text: "Lounge")

      find("body").send_keys("p")
      expect(page).to have_css(".concord-user-menu .user-menu")
    end

    it "searches the channel's messages from a chat channel" do
      chat_channel.add(admin)
      Fabricate(:chat_message, chat_channel: chat_channel, user: admin, message: "hello there")
      visit("/chat/c/-/#{chat_channel.id}")

      header.find(".concord-channel-header__search").click
      text_left, input_text_left = page.evaluate_script(<<~JS)
        (() => {
          const input = document.querySelector(".chat-channel__filter-bar input");
          return [
            document.querySelector(".chat-message-text").getBoundingClientRect().left,
            input.getBoundingClientRect().left + parseFloat(getComputedStyle(input).paddingLeft),
          ];
        })()
      JS
      expect(input_text_left).to be_within(1).of(text_left)
      expect(page).to have_css(".chat-channel__filter-bar input:focus")
      expect(page.evaluate_script(<<~JS)).to eq("solid")
        getComputedStyle(document.querySelector(".chat-channel__filter-bar .filter-input-container")).outlineStyle
      JS
      expect(page).to have_no_css(".concord-search-panel")
      screenshot("chat-search")

      header.find(".concord-channel-header__search").click
      expect(page).to have_no_css(".chat-channel__filter-bar")
    end

    it "shows the category" do
      category.update!(description: "Sit by the fire")
      visit("/c/#{category.slug}/#{category.id}")

      expect(page).to have_css(".list-controls")
      expect(page).to have_no_css(".list-controls .category-breadcrumb", visible: :visible)
      expect(page).to have_no_css(
        ".list-controls .notifications-tracking-trigger-btn",
        visible: :visible,
      )

      expect(header).to have_css(".concord-channel-header__name", text: "Lounge")
      expect(header).to have_css(".concord-channel-header__description", text: "Sit by the fire")
      expect(page).to have_no_css(".list-controls .edit-category", visible: :visible)
      screenshot("forum")

      header.find("[data-action-id='settings']").click
      expect(page).to have_current_path(%r{/c/#{category.slug}/edit})
    end

    it "centres a topic in the space beside the channel list" do
      topic = Fabricate(:topic, category:, title: "Best campfire songs")
      20.times { Fabricate(:post, topic:) }

      resize_window(width: 1920) do
        visit(topic.relative_url)
        expect(page).to have_css(".timeline-container")

        outlet, posts = page.evaluate_script(<<~JS)
          ["#main-outlet", ".container.posts"].map((s) => {
            const r = document.querySelector(s).getBoundingClientRect();
            return { left: r.left, right: r.right };
          })
        JS
        expect(posts["left"] - outlet["left"]).to be > 100
        expect(posts["left"] - outlet["left"]).to be_within(1).of(outlet["right"] - posts["right"])
        screenshot("topic-centred")

        find(".topic-footer-main-buttons .create").click
        expect(page).to have_css("#reply-control.open")
        if page.has_no_css?("#reply-control.hide-preview", wait: 0)
          find("#reply-control .toggle-preview").click
        end
        expect(page).to have_css("#reply-control.hide-preview")
        composer_left =
          page.evaluate_script(
            "document.querySelector('#reply-control').getBoundingClientRect().left",
          )
        expect(composer_left).to be_within(1).of(posts["left"])
        screenshot("topic-centred-composer")
      end
    end

    it "cuts the description short before the title" do
      long_category = Fabricate(:category, name: "The lounge by the fire where everyone sings")
      topic =
        Fabricate(
          :post,
          topic:
            Fabricate(
              :topic,
              category: long_category,
              title: "What are the very best campfire songs to know",
            ),
        ).topic

      resize_window(width: 1000) do
        visit(topic.relative_url)
        expect(header).to have_css(".concord-channel-header__name")

        title_cut, description_cut = page.evaluate_script(<<~JS)
          [".concord-channel-header__name", ".concord-channel-header__description"].map((s) => {
            const el = document.querySelector(s);
            return el.scrollWidth > el.clientWidth;
          })
        JS
        expect(title_cut).to eq(false)
        expect(description_cut).to eq(true)
      end
    end

    it "goes back to the forum channel from a topic" do
      topic =
        Fabricate(:post, topic: Fabricate(:topic, category:, title: "Best campfire songs")).topic
      visit(topic.relative_url)

      header.find(".concord-channel-header__back").click
      expect(page).to have_current_path(%r{/c/#{category.slug}/#{category.id}})
      expect(header).to have_css(".concord-channel-header__name", text: "Lounge")
    end

    it "draws emoji in a topic's title" do
      topic =
        Fabricate(
          :post,
          topic: Fabricate(:topic, category:, title: "Best campfire songs :fire: <b>"),
        ).topic
      visit(topic.relative_url)

      name = header.find(".concord-channel-header__name a")
      expect(name).to have_css("img.emoji")
      expect(name).to have_text("Best campfire songs")
      expect(name).to have_text("<b>")
      expect(name).to have_no_css("b")
    end

    it "shows a topic's title over its category" do
      topic =
        Fabricate(:post, topic: Fabricate(:topic, category:, title: "Best campfire songs")).topic
      visit(topic.relative_url)

      expect(header).to have_css(
        ".concord-channel-header__name a[href='#{topic.relative_url}/1']",
        text: "Best campfire songs",
      )
      expect(header).to have_css(
        ".concord-channel-header__description a[href='#{category.url}']",
        text: "Lounge",
      )
      expect(header).to have_css(
        ".concord-channel-header__back[href='#{category.url}'][title='Back to Lounge']",
      )
      screenshot("topic")

      expect(page).to have_css(
        ".topic-footer-main-buttons + * .notifications-tracking-trigger-btn, #topic-footer-buttons .notifications-tracking-trigger-btn",
      )

      find(".topic-footer-main-buttons .create").click
      expect(page).to have_css("#reply-control.open")
      screenshot("composer")
    end

    it "fills the window, with the sidebar under the server name" do
      visit("/latest")

      widths = page.evaluate_script(<<~JS)
        (() => {
          const rect = (s) => document.querySelector(s).getBoundingClientRect();
          return {
            window: window.innerWidth,
            outlet: rect("#main-outlet-wrapper").width,
            sidebar: rect(".sidebar-wrapper").left,
            server: rect(".concord-channel-header .concord-server-header").right,
            sidebarRight: rect(".sidebar-wrapper").right,
            content: rect("#main-outlet").left,
            channel:
              rect(".concord-channel-header__channel").left +
              parseFloat(getComputedStyle(document.querySelector(".concord-channel-header__channel")).paddingLeft),
          };
        })()
      JS

      expect(widths["outlet"]).to be_within(20).of(widths["window"])
      expect(widths["sidebar"]).to eq(0)
      expect(widths["sidebarRight"]).to be_within(1).of(widths["server"])
      expect(widths["content"]).to be_within(1).of(widths["channel"])
    end
  end

  describe "server name logo" do
    fab!(:logo) { Fabricate(:image_upload, width: 400, height: 120) }

    let(:server_header) { find(".concord-channel-header .concord-server-header") }

    before { SiteSetting.logo = logo }

    it "shows the site name when turned off" do
      theme.update_setting(:show_logo, false)
      theme.save!
      visit("/latest")

      expect(server_header).to have_css(".concord-server-header__title", text: SiteSetting.title)
      expect(server_header).to have_no_css(".concord-server-header__logo")
    end

    it "shows the logo at the name's height, with or without the buttons beside it" do
      height = <<~JS
        document.querySelector(".concord-channel-header .concord-server-header__logo img").getBoundingClientRect().height
      JS

      visit("/latest")
      expect(server_header).to have_css(
        ".concord-server-header__logo img[alt='#{SiteSetting.title}']",
      )
      expect(server_header).to have_no_css(".concord-server-header__title")
      expect(server_header).to have_css(".concord-server-header__create")
      with_buttons = page.evaluate_script(height)
      screenshot("server-logo")

      visit("/admin")
      expect(server_header).to have_no_css(".concord-server-header__create")
      expect(page.evaluate_script(height)).to be_within(1).of(with_buttons)
      expect(with_buttons).to be < 30
    end

    it "falls back to the site name when there's no logo" do
      SiteSetting.logo = nil
      visit("/latest")

      expect(server_header).to have_css(".concord-server-header__title", text: SiteSetting.title)
      expect(server_header).to have_no_css(".concord-server-header__logo")
    end
  end

  describe "home link" do
    let(:server_name) { find(".concord-channel-header .concord-server-header__name") }

    it "can be turned off" do
      theme.update_setting(:home_link, false)
      theme.save!
      visit("/c/#{category.slug}/#{category.id}")

      server_name.click
      expect(find(".concord-action-menu")).to have_css("[data-item-id='about']")
      expect(page).to have_no_css(".concord-action-menu [data-item-id='home']")
    end

    it "leads the server menu, and goes home" do
      visit("/c/#{category.slug}/#{category.id}")

      server_name.click
      expect(page).to have_css(
        ".concord-action-menu [data-item-id]:first-child[data-item-id='home']",
      )
      find(".concord-action-menu [data-item-id='home']").click
      expect(page).to have_current_path("/")
    end
  end

  describe "admin" do
    let(:header) { find(".concord-channel-header") }

    it "trades the channel buttons for a way out" do
      visit("/c/#{category.slug}/#{category.id}")
      expect(header).to have_css(".concord-server-header__dms")
      expect(header).to have_css(".concord-server-header__create")
      expect(header).to have_css("[data-action-id='member-list']")
      expect(header).to have_css(".concord-channel-header__search")
      expect(header).to have_no_css(".concord-channel-header__exit-admin")

      # Through the app, so there's a page to go back to.
      header.find(".concord-server-header__name").click
      find(".concord-action-menu [data-item-id='admin']").click
      expect(header).to have_css(".concord-channel-header__name", exact_text: "Admin")
      expect(header).to have_no_css(".concord-server-header__dms")
      expect(header).to have_no_css(".concord-server-header__create")
      expect(header).to have_no_css("[data-action-id='member-list']")
      expect(header).to have_no_css(".concord-channel-header__search")
      expect(page).to have_no_css(".concord-member-list")
      screenshot("admin-header")

      header.find(".concord-channel-header__exit-admin").click
      expect(page).to have_current_path("/c/#{category.slug}/#{category.id}")
      expect(header).to have_css(".concord-channel-header__search")
    end

    it "exits home when admin was the first page" do
      visit("/admin/users")

      header.find(".concord-channel-header__exit-admin").click
      expect(page).to have_no_current_path(%r{/admin})
      expect(header).to have_no_css(".concord-channel-header__exit-admin")
    end
  end

  describe "language switcher" do
    let(:actions) { find(".concord-channel-header__actions") }

    before do
      SiteSetting.default_locale = "en"
      SiteSetting.content_localization_supported_locales = "es|ja"
      SiteSetting.content_localization_enabled = true
    end

    it "shows core's switcher left of the header buttons, when core would" do
      SiteSetting.content_localization_language_switcher = "all"
      visit("/latest")

      switcher = actions.find(".concord-channel-header__language")
      expect(switcher).to have_css(".language-switcher__locale", text: "EN")
      expect(page.evaluate_script(<<~JS)).to eq(true)
        (() => {
          const switcher = document.querySelector(".concord-channel-header__language");
          const search = document.querySelector(".concord-channel-header__search");
          return switcher.getBoundingClientRect().right <= search.getBoundingClientRect().left;
        })()
      JS
      screenshot("language-switcher")

      switcher.find("button[data-identifier='language-switcher']").click
      expect(page).to have_css(".language-switcher-content [data-menu-option-id='ja']")
    end

    it "is hidden when core's is" do
      SiteSetting.content_localization_language_switcher = "anonymous"
      visit("/latest")

      expect(actions).to have_css(".concord-channel-header__search")
      expect(actions).to have_no_css(".concord-channel-header__language")
    end
  end

  describe "user panel" do
    it "puts the user's status emoji on their avatar" do
      SiteSetting.enable_user_status = true
      admin.set_status!("Out camping", "tent")
      visit("/latest")

      expect(find(".concord-user-panel__subtitle")).to have_text("Out camping")
      avatar, status = page.evaluate_script(<<~JS)
        [".concord-user-panel__avatar .avatar", ".concord-user-panel__avatar .user-status-background"]
          .map((s) => { const r = document.querySelector(s).getBoundingClientRect(); return { right: r.right, bottom: r.bottom }; })
      JS
      expect(status["right"]).to be_within(4).of(avatar["right"])
      expect(status["bottom"]).to be_within(2).of(avatar["bottom"])
      screenshot("user-panel-status")
    end

    it "shows the display name over the username, without saying either twice" do
      admin.update!(name: "Anne Admin")
      visit("/latest")

      panel = find(".concord-user-panel")
      expect(panel).to have_css(".concord-user-panel__name", exact_text: "Anne Admin")
      expect(panel).to have_css(".concord-user-panel__subtitle", exact_text: admin.username)

      admin.update!(name: "")
      visit("/latest")
      panel = find(".concord-user-panel")
      expect(panel).to have_css(".concord-user-panel__name", exact_text: admin.username)
      expect(panel).to have_no_css(".concord-user-panel__subtitle")
    end

    it "opens the notifications menu from the bell" do
      Fabricate(:notification, user: admin)
      visit("/latest")

      panel = find(".concord-user-panel")
      expect(panel).to have_css(
        ".concord-user-panel__name",
        text: admin.name.presence || admin.username,
      )
      expect(panel).to have_css(".concord-user-panel__notifications .badge-notification", text: "1")
      expect(panel).to have_no_css(
        ".concord-user-panel__avatar .badge-notification",
        visible: :visible,
      )
      screenshot("user-panel")

      panel.find(".concord-user-panel__notifications").click
      expect(page).to have_css(".concord-user-menu .user-menu .quick-access-panel")
      tabs_left, panel_left = page.evaluate_script(<<~JS)
        [".concord-user-menu .menu-tabs-container", ".concord-user-menu .quick-access-panel"]
          .map((s) => document.querySelector(s).getBoundingClientRect().left)
      JS
      expect(tabs_left).to be < panel_left
      expect(page).to have_no_css(".concord-user-menu #user-menu-button-profile", visible: :visible)
      screenshot("user-menu")
    end

    it "opens the profile menu from the user's name" do
      visit("/latest")

      find(".concord-user-panel__me").click
      menu = find(".concord-profile-menu #quick-access-profile")
      expect(menu).to have_css("li.preferences")
      expect(menu).to have_css("li.logout")
      expect(page.evaluate_script(<<~JS)).to eq("400")
        getComputedStyle(document.querySelector(".concord-profile-menu li.summary .item-label")).fontWeight
      JS
      screenshot("profile-menu")

      menu.find("li.preferences a").click
      expect(page).to have_current_path(%r{/u/#{admin.username}/preferences})
      expect(page).to have_no_css(".concord-profile-menu")
    end

    it "offers log in and sign up when signed out" do
      Capybara.reset_sessions!
      visit("/latest")

      expect(page).to have_css(".concord-user-panel .concord-user-panel__login")
      expect(page).to have_css(".concord-user-panel .concord-user-panel__signup")
    end

    it "has no member list when signed out" do
      Capybara.reset_sessions!
      visit("/c/#{category.slug}/#{category.id}")

      expect(page).to have_css(".concord-channel-header__name", text: category.name)
      expect(page).to have_no_css(".concord-channel-header [data-action-id='member-list']")
      expect(page).to have_no_css(".concord-member-list")
      expect(page).to have_no_css("body.concord-member-list-open")
    end

    it "leaves the log in and sign up pages to core" do
      Capybara.reset_sessions!

      %w[/login /signup].each do |path|
        visit(path)
        expect(page).to have_css(".d-header .home-logo-wrapper-outlet", visible: :visible)
        expect(page).to have_no_css(".concord-channel-header, .concord-member-list")
        expect(page).to have_no_css("body.concord-member-list-open")
        screenshot("auth#{path.tr("/", "-")}")
      end
    end
  end

  describe "member list" do
    fab!(:member) { Fabricate(:user, username: "camper") }
    fab!(:outsider) { Fabricate(:user, username: "stranger") }

    let(:list) { find(".concord-member-list") }

    before do
      chat_channel.add(member)
      DirectoryItem.refresh!
    end

    def section(id)
      list.find(".concord-member-list__section[data-section-id='#{id}']")
    end

    it "lists a chat channel's members, with online admins under their role" do
      visit("/chat/c/hangout/#{chat_channel.id}")

      expect(section("role-admins")).to have_css("[data-username='#{admin.username}']")
      expect(section("offline")).to have_css("[data-username='camper']")
      expect(list).to have_no_css("[data-username='stranger']")
      screenshot("member-list")
      expect(page.evaluate_script(<<~JS)).to eq("0px")
        getComputedStyle(document.querySelector(".full-page-chat")).borderRightWidth
      JS
    end

    it "lists everyone online in a public channel, but only members in a private one" do
      PresenceChannel.new("/chat/online").present(user_id: outsider.id, client_id: "stranger-tab")
      visit("/chat/c/hangout/#{chat_channel.id}")
      expect(section("online")).to have_css("[data-username='stranger']")

      category.set_permissions(admins: :full)
      category.save!
      visit("/chat/c/hangout/#{chat_channel.id}")
      expect(section("role-admins")).to have_css("[data-username='#{admin.username}']")
      expect(list).to have_no_css("[data-username='stranger']")
    end

    it "opens user cards from the list" do
      visit("/chat/c/hangout/#{chat_channel.id}")

      list.find("[data-username='camper'] .concord-member-list__name").click
      expect(page).to have_css(".user-card .user-profile-link", text: "camper")
      expect(page).to have_current_path(%r{/chat/c/hangout/})
      screenshot("member-card")
    end

    it "lists everyone on forum pages" do
      visit("/c/#{category.slug}/#{category.id}")

      expect(list).to have_css("[data-username='camper']")
      expect(list).to have_css("[data-username='stranger']")
    end

    it "counts you online anywhere on the site, not only in chat" do
      visit("/c/#{category.slug}/#{category.id}")
      expect(section("role-admins")).to have_css("[data-username='#{admin.username}']")

      channel_link("text-hangout").click
      expect(page).to have_css(".chat-composer")
      channel_link("forum-#{category.slug}").click
      expect(page).to have_css(".concord-channel-header__name", text: "Lounge")
      expect(section("role-admins")).to have_css("[data-username='#{admin.username}']")
    end

    it "hides and remembers being hidden" do
      visit("/latest")
      expect(page).to have_css(".concord-member-list")

      find(".concord-channel-header [data-action-id='member-list']").click
      expect(page).to have_no_css(".concord-member-list")

      visit("/latest")
      expect(page).to have_css(".concord-channel-header [data-action-id='member-list']")
      expect(page).to have_no_css(".concord-member-list")
    end
  end

  describe "small screens" do
    def opens_channel_list_from_header
      visit("/chat/c/hangout/#{chat_channel.id}")

      header = find(".concord-channel-header")
      expect(header).to have_css(".concord-channel-header__name", text: "hangout")
      expect(page).to have_no_css(".d-header .home-logo-wrapper-outlet", visible: :visible)
      expect(page).to have_no_css(".c-routes.--channel > .c-navbar-container", visible: :visible)

      screenshot("#{yield}-closed")

      header.find(".concord-channel-header__menu").click
      panel = find(".hamburger-panel")
      expect(panel).to have_css(".sidebar-section-link[data-link-name='forum-#{category.slug}']")
      expect(panel).to have_css(".concord-server-header")
      expect(panel).to have_no_css(".concord-user-panel", visible: :visible)
      # Let the slide-in finish before the screenshot.
      expect(page).to have_css(".hamburger-panel .concord-server-header__name", visible: :visible)
      sleep 0.5 if ENV["DCCK_SCREENSHOTS"]
      screenshot(yield)

      panel.find(".sidebar-section-link[data-link-name='forum-#{category.slug}']").click
      expect(page).to have_current_path(%r{/c/#{category.slug}/#{category.id}})
      expect(page).to have_no_css(".hamburger-panel")

      header.find(".concord-channel-header__user").click
      menu = find(".user-menu-dropdown-wrapper .user-menu", visible: :visible)
      expect(menu).to have_css("#user-menu-button-profile")
      sleep 0.5 if ENV["DCCK_SCREENSHOTS"]
      screenshot("#{yield}-user-menu")

      # It covers the header, so it closes from the shade beside it.
      find(".header-cloak").click(x: 10, y: 300)
      expect(page).to have_no_css(".user-menu-dropdown-wrapper")
    end

    it "keeps the header's buttons on screen with a long title", mobile: true do
      topic =
        Fabricate(
          :post,
          topic:
            Fabricate(
              :topic,
              category:,
              title: "What are the very best campfire songs everyone should know",
            ),
        ).topic
      visit(topic.relative_url)

      header = find(".concord-channel-header")
      expect(header).to have_css(".concord-channel-header__user")
      right = page.evaluate_script(<<~JS)
        document.querySelector(".concord-channel-header__user").getBoundingClientRect().right
      JS
      expect(right).to be <= page.evaluate_script("window.innerWidth")
      screenshot("mobile-long-title")
    end

    it "puts the user's status emoji on the header's avatar on phones", mobile: true do
      SiteSetting.enable_user_status = true
      admin.set_status!("Out camping", "tent")
      visit("/latest")

      expect(page).to have_css(".concord-channel-header__user .user-status-background")
      avatar, status = page.evaluate_script(<<~JS)
        [".concord-channel-header__user .avatar", ".concord-channel-header__user .user-status-background"]
          .map((s) => { const r = document.querySelector(s).getBoundingClientRect(); return { right: r.right, bottom: r.bottom }; })
      JS
      expect(status["right"]).to be_within(4).of(avatar["right"])
      expect(status["bottom"]).to be_within(2).of(avatar["bottom"])
      screenshot("mobile-header-status")
    end

    it "slides the member list in from the right on phones", mobile: true do
      visit("/chat/c/hangout/#{chat_channel.id}")

      expect(page).to have_no_css(".concord-member-list")
      find(".concord-channel-header [data-action-id='member-list']").click
      list = find(".concord-member-list.--slide-in")
      # Members load before chat's presence does, so admin is listed offline
      # first and then re-rendered among the online; wait for that, or the
      # click below can land on the row being replaced.
      expect(list).to have_css(
        ".concord-member-list__member:not(.--offline)[data-username='#{admin.username}']",
      )
      expect(page).to have_no_css("body.concord-member-list-open")
      sleep 0.5 if ENV["DCCK_SCREENSHOTS"]
      screenshot("mobile-member-list")

      list.find("[data-username='#{admin.username}'] .concord-member-list__name").click
      expect(page).to have_css(".user-card")
      expect(page).to have_no_css(".concord-member-list")
    end

    it "searches from the full search page on phones", mobile: true do
      visit("/latest")

      find(".concord-channel-header__search").click
      expect(page).to have_current_path(%r{^/search})
      expect(page).to have_css(".full-page-search")
      expect(page).to have_no_css(".concord-search-panel")
    end

    it "folds a channel's extra actions into a more menu on phones", mobile: true do
      visit("/chat/c/hangout/#{chat_channel.id}")

      header = find(".concord-channel-header")
      expect(header).to have_css(".concord-channel-header__name", text: "hangout")
      expect(header).to have_no_css("[data-action-id='pins']", visible: :visible)
      expect(header).to have_no_css("[data-action-id='settings']", visible: :visible)
      expect(header).to have_css("[data-action-id='member-list']", visible: :visible)
      # The menu leads the row's buttons.
      expect(
        header.first(".concord-channel-header__actions > .btn", visible: :visible)[:class],
      ).to include("concord-channel-header__more")

      header.find(".concord-channel-header__more").click
      menu = find(".concord-action-menu")
      expect(menu).to have_css("[data-item-id='pins']")
      expect(menu).to have_css("[data-item-id='settings']")
      screenshot("mobile-more-menu")

      menu.find("[data-item-id='pins']").click
      expect(page).to have_current_path(%r{/chat/c/hangout/#{chat_channel.id}/pins})
    end

    it "keeps a lone action in the header row on phones", mobile: true do
      visit("/c/#{category.slug}/#{category.id}")

      header = find(".concord-channel-header")
      expect(header).to have_css("[data-action-id='settings']", visible: :visible)
      expect(header).to have_no_css(".concord-channel-header__more")
    end

    it "keeps the server name at the top of the channel list on phones", mobile: true do
      30.times { |i| Fabricate(:category, name: "Campsite #{i.to_s.rjust(2, "0")}") }
      visit("/latest")
      find(".concord-channel-header__menu").click
      expect(page).to have_css(".hamburger-panel .concord-server-header__name", visible: :visible)

      offsets = page.evaluate_script(<<~JS)
        (() => {
          const name = document.querySelector(".hamburger-panel .concord-server-header");
          let scroller = name.parentElement;
          while (scroller && scroller.scrollHeight <= scroller.clientHeight) {
            scroller = scroller.parentElement;
          }
          const before = name.getBoundingClientRect().top;
          scroller.scrollTop = 600;
          return [before, name.getBoundingClientRect().top, scroller.scrollTop];
        })()
      JS
      expect(offsets.last).to be > 0
      expect(offsets[1]).to be_within(1).of(offsets.first)
      sleep 0.5 if ENV["DCCK_SCREENSHOTS"]
      screenshot("mobile-sticky-name")
    end

    it "slides the channel list in on a slow phone", mobile: true do
      20.times { |i| Fabricate(:category, name: "Campsite #{i.to_s.rjust(2, "0")}") }
      visit("/latest")
      menu = find(".concord-channel-header__menu")
      page.driver.with_playwright_page do |pw|
        pw
          .context
          .new_cdp_session(pw)
          .send_message("Emulation.setCPUThrottlingRate", params: { rate: 6 })
      end

      # Where the list is drawn each frame once its channels are in it.
      page.execute_script(<<~JS, menu)
        window.__dcckFrames = [];
        const record = () => {
          const panel = document.querySelector(".hamburger-panel .menu-panel");
          if (panel?.querySelector(".sidebar-section-link")) {
            window.__dcckFrames.push(Math.round(panel.getBoundingClientRect().left));
          }
          if (window.__dcckFrames.at(-1) !== 0) {
            requestAnimationFrame(record);
          }
        };
        arguments[0].click();
        requestAnimationFrame(record);
      JS

      expect(page).to have_css(".hamburger-panel .sidebar-section-link")
      try_until_success { expect(page.evaluate_script("window.__dcckFrames.at(-1)")).to eq(0) }
      frames = page.evaluate_script("window.__dcckFrames")
      expect(frames.count { |left| left < 0 }).to be > 3
    end

    it "closes the channel list when the server menu navigates on phones", mobile: true do
      visit("/latest")
      find(".concord-channel-header__menu").click
      find(".hamburger-panel .concord-server-header__name").click
      find(".concord-action-menu .btn", text: "About").click

      expect(page).to have_current_path("/about")
      expect(page).to have_no_css(".hamburger-panel")
      expect(
        page.evaluate_script("document.documentElement.classList.contains('scroll-lock')"),
      ).to eq(false)
    end

    it "scrolls the current channel into view in the channel list on phones", mobile: true do
      campsites =
        40.times.map { |i| Fabricate(:category, name: "Campsite #{i.to_s.rjust(2, "0")}") }
      visit(campsites.last.url)
      find(".concord-channel-header__menu").click

      expect(page).to have_css(".hamburger-panel .sidebar-section-link.active")
      sleep 0.5
      expect(row_in_view?(".hamburger-panel")).to eq(true)
      screenshot("mobile-active-in-view")
    end

    it "opens a channel's menu with a long press on phones", mobile: true do
      visit("/latest")
      find(".concord-channel-header__menu").click
      row = find(".hamburger-panel .sidebar-section-link[data-link-name='text-hangout']")

      page.execute_script(<<~JS, row)
        const row = arguments[0];
        const rect = row.getBoundingClientRect();
        const at = { bubbles: true, pointerType: "touch", clientX: rect.left + 20, clientY: rect.top + 10 };
        row.dispatchEvent(new PointerEvent("pointerdown", at));
        window.__dcckRelease = () => {
          row.dispatchEvent(new PointerEvent("pointerup", at));
          row.click();
        };
      JS
      expect(page).to have_css(".concord-action-menu .btn", text: "Mark as read")
      page.execute_script("window.__dcckRelease()")

      expect(page).to have_current_path("/latest")
      expect(page).to have_css(".concord-action-menu .btn", text: "Mark as read")
      screenshot("mobile-long-press")
      labels_left = page.evaluate_script(<<~JS)
        [...document.querySelectorAll(".concord-action-menu .btn .d-button-label")].map((l) => Math.round(l.getBoundingClientRect().left))
      JS
      expect(labels_left.uniq.size).to eq(1)
    end

    it "opens the channel list from the header on phones", mobile: true do
      opens_channel_list_from_header { "mobile" }
    end

    it "opens the channel list from the header in a narrow window" do
      resize_window(width: 700) { opens_channel_list_from_header { "narrow" } }
    end
  end
end
