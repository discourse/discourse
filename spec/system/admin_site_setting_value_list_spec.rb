# frozen_string_literal: true

describe "Admin Site Setting Value Lists" do
  fab!(:admin)
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before { sign_in(admin) }

  describe "reordering items in value lists" do
    context "when on non-touch devices" do
      it "hides reorder buttons by default for simple-list settings" do
        settings_page.visit("top_menu")
        expect(page).to have_css("html.discourse-no-touch")
        expect(settings_page).to have_hidden_reorder_buttons("top_menu")
      end

      it "hides reorder buttons by default for emoji-list settings" do
        settings_page.visit("default_emoji_reactions")
        expect(page).to have_css("html.discourse-no-touch")
        expect(settings_page).to have_hidden_reorder_buttons("default_emoji_reactions")
      end
    end

    context "when on touch devices", mobile: true do
      it "shows reorder buttons by default for simple-list settings" do
        settings_page.visit("top_menu")
        expect(page).to have_css("html.discourse-touch")
        expect(settings_page).to have_visible_reorder_buttons("top_menu")
      end

      it "shows reorder buttons by default for emoji-list settings" do
        settings_page.visit("default_emoji_reactions")
        expect(page).to have_css("html.discourse-touch")
        expect(settings_page).to have_visible_reorder_buttons("default_emoji_reactions")
      end
    end
  end
end
