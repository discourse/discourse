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

    # The reorder control used to be revealed on hover, which a touch screen has
    # no way to trigger, so these settings were unreorderable on a phone. It is
    # permanent on every device behind the change, and that parity is what the
    # first four guard.
    #
    # TODO (ui-kit-reorderable-list-cleanup) fold these over the contexts above
    # once the change ships.
    context "when enable_new_reordering_controls is enabled" do
      before { SiteSetting.enable_new_reordering_controls = true }

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

      # The menu is portaled and positioned asynchronously, so focusing a
      # destination before it has been placed asks the browser to scroll to
      # wherever the float still sits, which throws the reader to the top of the
      # settings page they were working in.
      it "does not scroll the page when the move menu opens" do
        # Short enough that the settings page has somewhere to scroll from, which
        # is the whole of what this measures.
        resize_window(height: 700) do
          settings_page.visit_category("basic")
          expect(settings_page).to have_reorder_handle("top_menu")

          page.execute_script(<<~JS)
            document
              .querySelector("[data-setting='top_menu'] .d-reorderable-list__handle")
              .scrollIntoView({ block: "center" });
          JS
          before = page.evaluate_script("Math.round(window.scrollY)")
          expect(before).to be > 0

          settings_page.open_reorder_menu("top_menu")

          expect(page).to have_css(".d-reorderable-list__move-item:focus")
          expect(page.evaluate_script("Math.round(window.scrollY)")).to eq(before)
        end
      end

      # A pointer press does not set focus-visible, and the menu places focus on
      # a destination as it opens, so a highlight keyed on that alone leaves a
      # mouse user with a focused item and no way to see which one it is.
      it "highlights the focused destination when the menu is opened by pointer" do
        settings_page.visit_category("basic")
        expect(settings_page).to have_reorder_handle("top_menu")

        settings_page.open_reorder_menu("top_menu")

        expect(page).to have_css(".d-reorderable-list__move-item:focus")
        background = page.evaluate_script(<<~JS)
          getComputedStyle(document.querySelector(".d-reorderable-list__move-item:focus"))
            .backgroundColor
        JS
        expect(background).not_to eq("rgba(0, 0, 0, 0)")
      end
    end
  end
end
