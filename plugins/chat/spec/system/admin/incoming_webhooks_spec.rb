# frozen_string_literal: true

describe "Admin Chat Incoming Webhooks" do
  fab!(:current_user, :admin)
  fab!(:chat_channel_1, :chat_channel)

  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:admin_incoming_webhooks_page) { PageObjects::Pages::AdminIncomingWebhooks.new }
  let(:d_page_header) { PageObjects::Components::DPageHeader.new }

  before do
    chat_system_bootstrap(current_user)
    sign_in(current_user)
  end

  it "filters channels by title and creates a webhook for the selected channel" do
    # The chooser only shows the filter when it has at least ten options.
    other_channel = Fabricate(:chat_channel, chatable: chat_channel_1.chatable)
    Fabricate.times(8, :chat_channel, chatable: chat_channel_1.chatable)

    admin_incoming_webhooks_page.visit
    expect(d_page_header).to be_visible

    admin_incoming_webhooks_page.click_new
    expect(d_page_header).to be_hidden

    admin_incoming_webhooks_page.form.field("name").fill_in("Test webhook")
    admin_incoming_webhooks_page.form.field("description").fill_in("Some test content")
    admin_incoming_webhooks_page.form.field("username").fill_in("system")
    chooser = admin_incoming_webhooks_page.channel_chooser
    chooser.expand
    expect(chooser).to have_option_value(other_channel.id)

    chooser.search(chat_channel_1.title)
    expect(chooser).to have_option_value(chat_channel_1.id)
    expect(chooser).to have_no_option_value(other_channel.id)
    chooser.select_row_by_value(chat_channel_1.id)
    chooser.collapse
    # TODO (martin) Add an emoji selection once Joffrey's emoji selector
    # unification has landed in core.

    admin_incoming_webhooks_page.form.submit

    expect(page).to have_content(I18n.t("js.chat.incoming_webhooks.created"))
    expect(page).to have_content(Chat::IncomingWebhook.find_by(name: "Test webhook").url)
  end

  describe "existing webhooks" do
    fab!(:webhook_1, :incoming_chat_webhook)
    fab!(:webhook_2, :incoming_chat_webhook)

    it "lists existing webhooks and saves edits to a webhook" do
      admin_incoming_webhooks_page.visit
      expect(page).to have_content(webhook_1.name)
      expect(page).to have_content(webhook_1.chat_channel.title)
      expect(page).to have_content(webhook_2.name)
      expect(page).to have_content(webhook_2.chat_channel.title)

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
      expect(page).to have_css(".incoming-chat-webhooks-row[data-webhook-id='#{webhook_2.id}']")
      expect(page).to have_no_css(".incoming-chat-webhooks-row[data-webhook-id='#{webhook_1.id}']")
    end
  end
end
