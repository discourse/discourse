# frozen_string_literal: true

RSpec.describe "Chat Integration Rule Tags" do
  with_select_controls(false)

  fab!(:admin)
  fab!(:tag1) { Fabricate(:tag, name: "support") }
  fab!(:tag2) { Fabricate(:tag, name: "bug") }
  fab!(:category)
  fab!(:channel) do
    DiscourseChatIntegration::Channel.create!(
      provider: "discord",
      data: {
        name: "test-channel",
        webhook_url: "https://discord.com/api/webhooks/test",
      },
    )
  end

  let(:tag_chooser) { PageObjects::Components::SelectKit.new(".tag-chooser") }
  let(:rule_modal) { PageObjects::Modals::Base.new }

  before do
    SiteSetting.tagging_enabled = true
    SiteSetting.chat_integration_enabled = true
    SiteSetting.chat_integration_discord_enabled = true
    sign_in(admin)
  end

  it "can edit a rule with existing tags and add new ones" do
    DiscourseChatIntegration::Rule.create!(
      channel: channel,
      filter: "watch",
      category_id: category.id,
      tags: ["support"],
    )

    visit("/admin/plugins/discourse-chat-integration/providers/discord")

    within(".d-table.channel-rules-table .d-table__row") do
      expect(page).to have_content("support")
      find(".edit").click
    end

    expect(rule_modal).to be_open

    tag_chooser.expand
    tag_chooser.search("bug")
    tag_chooser.select_row_by_name("bug")

    expect(tag_chooser.component).to have_content("support")
    expect(tag_chooser.component).to have_content("bug")

    tag_chooser.collapse
    find("#save-rule").click

    expect(rule_modal).to be_closed

    within(".channel-details table tbody tr") { expect(page).to have_text("support, bug") }
  end

  context "with the new select controls" do
    with_select_controls(true)

    let(:d_tag_chooser) { PageObjects::Components::UiKit::DSelect.at(".tag-chooser") }

    it "edits a rule's tags with the new select controls" do
      DiscourseChatIntegration::Rule.create!(
        channel: channel,
        filter: "watch",
        category_id: category.id,
        tags: ["support"],
      )

      visit("/admin/plugins/discourse-chat-integration/providers/discord")

      within(".d-table.channel-rules-table .d-table__row") do
        expect(page).to have_content("support")
        find(".edit").click
      end

      expect(rule_modal).to be_open
      expect(page).to have_css(".tag-chooser .d-select__chip[data-name='support']")

      d_tag_chooser.search("bug")
      d_tag_chooser.select_name("bug")
      d_tag_chooser.close

      expect(page).to have_css(".tag-chooser .d-select__chip[data-name='support']")
      expect(page).to have_css(".tag-chooser .d-select__chip[data-name='bug']")

      find("#save-rule").click

      expect(rule_modal).to be_closed

      within(".channel-details table tbody tr") { expect(page).to have_text("support, bug") }
    end
  end
end
