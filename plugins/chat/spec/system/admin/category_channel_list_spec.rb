# frozen_string_literal: true

RSpec.describe "Admin category channels list", type: :system do
  fab!(:current_user, :admin)
  fab!(:category)
  fab!(:channel_1) { Fabricate(:chat_channel, chatable: category, emoji: "goat") }
  fab!(:channel_2) { Fabricate(:chat_channel, chatable: category) }
  fab!(:channel_3, :chat_channel)

  before do
    # We are only showing the Chat tab on the new category UI, not the old one
    SiteSetting.enable_simplified_category_creation = true
    chat_system_bootstrap
    sign_in(current_user)
  end

  context "when a category has no chat channels" do
    fab!(:category_2, :category)

    it "shows a message saying that there are no chat channels" do
      visit "#{category_2.slug_url_without_id}/edit/chat"
      expect(page).to have_content(
        html_translation_to_text(
          I18n.t(
            "js.chat.edit_category.no_channels_body",
            chatBrowseUrl: "#{Discourse.base_path}/chat/browse/open",
          ),
        ),
      )
    end
  end

  context "when a category has chat channels" do
    it "shows a list of chat channels and opens the channel settings" do
      visit "#{category.slug_url_without_id}/edit/general"
      PageObjects::Components::DToggleSwitch.new(".category-show-advanced-tabs-toggle").toggle
      page.find(".edit-category-chat").click

      expect(page.find(".d-table__row[data-channel-id='#{channel_1.id}']")).to have_content(
        channel_1.title,
      )
      expect(page.find(".d-table__row[data-channel-id='#{channel_2.id}']")).to have_content(
        channel_2.title,
      )
      expect(page).to have_no_css(".d-table__row[data-channel-id='#{channel_3.id}']")
      expect(page.find(".d-table__row[data-channel-id='#{channel_1.id}']")).to have_css(
        "img.emoji[title='goat']",
      )

      page.find(
        ".d-table__row[data-channel-id='#{channel_1.id}'] .d-table__cell-actions .btn",
      ).click

      expect(page).to have_css(".c-channel-settings")
    end
  end

  context "when a category has subcategories with chat channels" do
    fab!(:subcategory) { Fabricate(:category, parent_category: category) }
    fab!(:subcategory_channel) { Fabricate(:chat_channel, chatable: subcategory) }

    it "shows subcategory channels by default with toggle visible" do
      visit "#{category.slug_url_without_id}/edit/chat"

      expect(page).to have_css(".edit-category-chat__subcategory-toggle")
      expect(page).to have_css(".d-table__row[data-channel-id='#{channel_1.id}']")
      expect(page).to have_css(".d-table__row[data-channel-id='#{channel_2.id}']")
      expect(page).to have_css(".d-table__row[data-channel-id='#{subcategory_channel.id}']")
      expect(page.find(".d-table__row[data-channel-id='#{subcategory_channel.id}']")).to have_css(
        ".edit-category-chat__subcategory-badge",
        text: subcategory.name,
      )
    end

    it "hides subcategory channels when toggle is clicked" do
      visit "#{category.slug_url_without_id}/edit/chat"

      expect(page).to have_css(".d-table__row[data-channel-id='#{subcategory_channel.id}']")

      PageObjects::Components::DToggleSwitch.new(
        ".edit-category-chat__subcategory-toggle .d-toggle-switch__checkbox",
      ).toggle

      expect(page).to have_no_css(".d-table__row[data-channel-id='#{subcategory_channel.id}']")
      expect(page).to have_css(".d-table__row[data-channel-id='#{channel_1.id}']")
      expect(page).to have_css(".d-table__row[data-channel-id='#{channel_2.id}']")
    end
  end

  context "when a category has no subcategory channels" do
    it "does not show the subcategory toggle" do
      visit "#{category.slug_url_without_id}/edit/chat"

      expect(page).to have_css(".d-table__row[data-channel-id='#{channel_1.id}']")
      expect(page).to have_no_css(".edit-category-chat__subcategory-toggle")
    end
  end
end
