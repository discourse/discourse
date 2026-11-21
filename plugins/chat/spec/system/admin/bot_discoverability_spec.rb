# frozen_string_literal: true

RSpec.describe "Manage bot chat discovery" do
  fab!(:admin)
  fab!(:member, :user)

  let(:form) { PageObjects::Components::FormKit.new(".admin-bot-form") }
  let(:admin_user) { PageObjects::Pages::AdminUser.new }
  let(:toggle) do
    PageObjects::Components::DToggleSwitch.new(".interactive-bot .d-toggle-switch__checkbox")
  end
  let(:chat) { PageObjects::Pages::Chat.new }
  let(:toasts) { PageObjects::Components::Toasts.new }

  before do
    chat_system_bootstrap(admin)
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.enable_names = false
  end

  it "lets admins choose whether members can find a bot when starting a chat" do
    sign_in(admin)
    visit "/admin/users/bots/new"
    form.field("username").fill_in("discoverable_bot")
    expect(form.field("interactive_bot")).to be_unchecked
    form.field("interactive_bot").check
    form.submit
    expect(toasts).to have_success(
      I18n.t("admin_js.admin.users.bots.created", username: "discoverable_bot"),
    )
    bot = User.find_by!(username: "discoverable_bot")

    sign_in(member)
    visit "/"
    chat.open_new_message
    chat.message_creator.filter(bot.username)
    expect(chat.message_creator).to be_listing(bot)

    sign_in(admin)
    admin_user.visit(bot)
    expect(toggle).to be_checked
    toggle.toggle
    try_until_success { expect(bot.reload).not_to be_interactive_bot }

    sign_in(member)
    visit "/"
    chat.open_new_message
    chat.message_creator.filter(bot.username)
    expect(chat.message_creator).to be_not_listing(bot)
  end

  it "lets an admin remove an existing chat-only listing without enabling notifications" do
    bot = Fabricate(:bot)
    Chat::DiscoverableBot.create!(user: bot)
    sign_in(admin)
    admin_user.visit(bot)

    expect(toggle).to be_unchecked
    legacy_toggle =
      PageObjects::Components::DToggleSwitch.new(
        ".chat-bot-discoverability .d-toggle-switch__checkbox",
      )
    expect(legacy_toggle).to be_checked
    legacy_toggle.toggle

    try_until_success { expect(Chat::DiscoverableBot.exists?(user_id: bot.id)).to eq(false) }
    expect(bot.reload).not_to be_interactive_bot
  end
end
