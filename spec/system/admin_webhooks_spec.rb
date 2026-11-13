#frozen_string_literal: true

describe "Admin Webhooks Page" do
  with_select_controls(false)

  fab!(:admin)
  fab!(:tag)

  let(:webhooks_page) { PageObjects::Pages::AdminWebhooks.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.tagging_enabled = true
    Fabricate(:web_hook, payload_url: "https://www.example.com/1")

    sign_in(admin)
  end

  it "shows a list of webhooks" do
    webhooks_page.visit_page

    expect(webhooks_page).to have_webhook_listed("https://www.example.com/1")
  end

  it "can add a new webhook" do
    webhooks_page.visit_page
    webhooks_page.add_webhook(payload_url: "https://www.example.com/2")

    expect(webhooks_page).to have_webhook_details("https://www.example.com/2")

    webhooks_page.click_back

    expect(webhooks_page).to have_webhook_listed("https://www.example.com/2")
  end

  it "can edit existing webhooks" do
    webhooks_page.visit_page
    webhooks_page.click_edit("https://www.example.com/1")
    webhooks_page.edit_payload_url("https://www.example.com/3")

    expect(webhooks_page).to have_webhook_listed("https://www.example.com/3")
  end

  it "can add a webhook with a tag filter" do
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
  end

  it "persists tag filters when re-editing a webhook" do
    tag_chooser = PageObjects::Components::SelectKit.new(".tag-chooser")

    webhooks_page.visit_page
    webhooks_page.click_add

    tag_chooser.expand
    tag_chooser.search(tag.name)
    tag_chooser.select_row_by_name(tag.name)

    webhooks_page.fill_payload_url("https://www.example.com/5")
    webhooks_page.click_save

    expect(webhooks_page).to have_webhook_details("https://www.example.com/5")

    webhooks_page.click_back
    webhooks_page.click_edit("https://www.example.com/5")

    expect(tag_chooser).to have_selected_name(tag.name)
  end

  it "can delete webhooks" do
    webhooks_page.visit_page
    webhooks_page.click_delete("https://www.example.com/1")

    dialog.click_danger

    expect(webhooks_page).to have_no_webhook_listed("https://www.example.com/1")
  end

  context "with the new select controls" do
    with_select_controls(true)

    let(:form) { PageObjects::Components::FormKit.new(".form-kit") }

    it "can add a webhook with a tag filter with the new select controls" do
      webhooks_page.visit_page
      webhooks_page.click_add

      expect(form.field("tags").component).to have_css(".form-kit__control-tag-chooser.d-select")

      form.field("tags").select(tag.name)

      expect(form.field("tags")).to have_selected_names(tag.name)

      webhooks_page.fill_payload_url("https://www.example.com/4")
      webhooks_page.click_save

      expect(webhooks_page).to have_webhook_details("https://www.example.com/4")

      webhook = WebHook.find_by(payload_url: "https://www.example.com/4")
      expect(webhook.tags).to contain_exactly(tag)
    end

    it "persists tag filters when re-editing a webhook with the new select controls" do
      webhooks_page.visit_page
      webhooks_page.click_add

      form.field("tags").select(tag.name)

      webhooks_page.fill_payload_url("https://www.example.com/5")
      webhooks_page.click_save

      expect(webhooks_page).to have_webhook_details("https://www.example.com/5")

      webhooks_page.click_back
      webhooks_page.click_edit("https://www.example.com/5")

      expect(form.field("tags")).to have_selected_names(tag.name)
    end
  end
end
