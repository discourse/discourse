# frozen_string_literal: true

describe "Admin Site Setting Value Lists" do
  fab!(:admin)
  let(:settings_page) { PageObjects::Pages::AdminSiteSettings.new }

  before { sign_in(admin) }

  # The reorder control used to be revealed on hover, which a touch screen has
  # no way to trigger, so these settings were unreorderable on a phone. It is
  # now permanent on every device, and that parity is what these guard.
  describe "reordering items in value lists" do
    context "when on non-touch devices" do
      it "shows the reorder handle for simple-list settings" do
        settings_page.visit("top_menu")
        expect(page).to have_css("html.discourse-no-touch")
        expect(settings_page).to have_reorder_handle("top_menu")
      end

      it "shows the reorder handle for emoji-list settings" do
        settings_page.visit("default_emoji_reactions")
        expect(page).to have_css("html.discourse-no-touch")
        expect(settings_page).to have_reorder_handle("default_emoji_reactions")
      end
    end

    context "when on touch devices", mobile: true do
      it "shows the same reorder handle for simple-list settings" do
        settings_page.visit("top_menu")
        expect(page).to have_css("html.discourse-touch")
        expect(settings_page).to have_reorder_handle("top_menu")
      end

      it "shows the same reorder handle for emoji-list settings" do
        settings_page.visit("default_emoji_reactions")
        expect(page).to have_css("html.discourse-touch")
        expect(settings_page).to have_reorder_handle("default_emoji_reactions")
      end
    end
  end
end
