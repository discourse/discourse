#frozen_string_literal: true

describe "Admin Webhooks Page" do
  fab!(:admin)
  fab!(:tag)

  let(:webhooks_page) { PageObjects::Pages::AdminWebhooks.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.tagging_enabled = true
    Fabricate(:web_hook, payload_url: "https://www.example.com/1")

    sign_in(admin)
  end

  it "lets an admin list, create, edit, and delete webhooks" do
    webhooks_page.visit_page

    expect(webhooks_page).to have_webhook_listed("https://www.example.com/1")

    webhooks_page.add_webhook(payload_url: "https://www.example.com/2")

    expect(webhooks_page).to have_webhook_details("https://www.example.com/2")

    webhooks_page.click_back

    expect(webhooks_page).to have_webhook_listed("https://www.example.com/2")

    webhooks_page.click_edit("https://www.example.com/1")
    webhooks_page.edit_payload_url("https://www.example.com/3")

    expect(webhooks_page).to have_webhook_listed("https://www.example.com/3")

    webhooks_page.click_delete("https://www.example.com/3")

    dialog.click_danger

    expect(webhooks_page).to have_no_webhook_listed("https://www.example.com/3")
    expect(webhooks_page).to have_webhook_listed("https://www.example.com/2")

    webhooks_page.click_delete("https://www.example.com/2")
    dialog.click_danger

    expect(page).to have_css(
      ".admin-config-area-empty-list",
      text: I18n.t("admin_js.admin.web_hooks.none"),
    )
  end

  it "lets an admin create a webhook with a tag filter that persists when re-editing" do
    tag_chooser = PageObjects::Components::SelectKit.new(".tag-chooser")

    webhooks_page.visit_page
    webhooks_page.click_add

    expect(tag_chooser).to be_visible

    tag_chooser.expand
    tag_chooser.search(tag.name)
    tag_chooser.select_row_by_name(tag.name)

    webhooks_page.fill_payload_url("https://www.example.com/4")
    webhooks_page.click_save

    expect(webhooks_page).to have_webhook_details("https://www.example.com/4")

    webhook = WebHook.find_by(payload_url: "https://www.example.com/4")
    expect(webhook.tags).to contain_exactly(tag)

    webhooks_page.click_back
    webhooks_page.click_edit("https://www.example.com/4")

    expect(tag_chooser).to have_selected_name(tag.name)
  end
end
