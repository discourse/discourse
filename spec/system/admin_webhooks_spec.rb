#frozen_string_literal: true

describe "Admin Webhooks Page", type: :system do
  fab!(:admin)

  let(:webhooks_page) { PageObjects::Pages::AdminWebhooks.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
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
    webhooks_page.click_save

    expect(webhooks_page).to have_webhook_listed("https://www.example.com/3")
  end

  it "can delete webhooks" do
    webhooks_page.visit_page
    webhooks_page.click_delete("https://www.example.com/1")

    dialog.click_danger

    expect(webhooks_page).to have_no_webhook_listed("https://www.example.com/1")
  end
end
