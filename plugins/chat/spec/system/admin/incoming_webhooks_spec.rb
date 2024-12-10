# frozen_string_literal: true

describe "Admin Chat Incoming Webhooks", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:chat_channel_1) { Fabricate(:chat_channel) }

  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:admin_incoming_webhooks_page) { PageObjects::Pages::AdminIncomingWebhooks.new }
  let(:admin_header) { PageObjects::Components::AdminHeader.new }

  before do
    chat_system_bootstrap(current_user)
    sign_in(current_user)
  end

  it "can create incoming webhooks" do
    admin_incoming_webhooks_page.visit

    expect(admin_header).to be_visible

    admin_incoming_webhooks_page.click_new

    expect(admin_header).to be_hidden

    admin_incoming_webhooks_page.form.field("name").fill_in("Test webhook")
    admin_incoming_webhooks_page.form.field("description").fill_in("Some test content")
    admin_incoming_webhooks_page.form.field("username").fill_in("system")
    admin_incoming_webhooks_page.channel_chooser.expand
    admin_incoming_webhooks_page.channel_chooser.select_row_by_value(chat_channel_1.id)
    admin_incoming_webhooks_page.channel_chooser.collapse
    # TODO (martin) Add an emoji selection once Joffrey's emoji selector
    # unification has landed in core.

    admin_incoming_webhooks_page.form.submit

    expect(page).to have_content(I18n.t("js.chat.incoming_webhooks.created"))
    expect(page).to have_content(Chat::IncomingWebhook.find_by(name: "Test webhook").url)
  end

  describe "existing webhooks" do
    fab!(:webhook_1) { Fabricate(:incoming_chat_webhook) }
    fab!(:webhook_2) { Fabricate(:incoming_chat_webhook) }

    it "can list existing incoming webhooks" do
      admin_incoming_webhooks_page.visit
      expect(page).to have_content(webhook_1.name)
      expect(page).to have_content(webhook_1.chat_channel.title)
      expect(page).to have_content(webhook_2.name)
      expect(page).to have_content(webhook_2.chat_channel.title)
    end

    it "can edit an existing incoming webhook" do
      admin_incoming_webhooks_page.visit
      admin_incoming_webhooks_page
        .list_row(webhook_1.id)
        .find(".admin-chat-incoming-webhooks-edit")
        .click
      expect(admin_incoming_webhooks_page.form.field("name").value).to eq(webhook_1.name)
      admin_incoming_webhooks_page.form.field("name").fill_in("Wow so cool")
      admin_incoming_webhooks_page.form.submit
      expect(page).to have_content(I18n.t("js.chat.incoming_webhooks.saved"))
      admin_incoming_webhooks_page.visit
      expect(page).to have_content("Wow so cool")
    end

    it "can delete an existing incoming webhook" do
      admin_incoming_webhooks_page.visit
      admin_incoming_webhooks_page
        .list_row(webhook_1.id)
        .find(".admin-chat-incoming-webhooks-delete")
        .click
      dialog.click_danger
      expect(page).not_to have_content(webhook_1.name)
    end
  end
end
