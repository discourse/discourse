# frozen_string_literal: true

describe "Discourse dev tools", type: :system do
  let(:toolbar) { PageObjects::Components::DevTools::Toolbar.new }
  let(:plugin_outlet_debug) { PageObjects::Components::DevTools::PluginOutletDebug.new }
  let(:block_debug) { PageObjects::Components::DevTools::BlockDebug.new }

  describe "toolbar" do
    it "can be enabled and disabled" do
      visit("/latest")
      expect(page).to have_css("#site-logo")
      expect(toolbar).to have_no_toolbar

      toolbar.enable
      expect(toolbar).to have_toolbar

      toolbar.disable
      expect(toolbar).to have_no_toolbar
      expect(page).to have_css("#site-logo")
    end
  end

  describe "plugin outlet debugging" do
    it "shows plugin outlet overlays with tooltips" do
      visit("/latest")
      toolbar.enable
      toolbar.toggle_plugin_outlets

      expect(plugin_outlet_debug).to have_outlets(minimum: 10)

      plugin_outlet_debug.hover_outlet("home-logo-contents__before")
      expect(plugin_outlet_debug).to have_tooltip
      expect(plugin_outlet_debug).to have_arg(key: "@title")
      expect(plugin_outlet_debug).to have_arg_value(value: "\"#{SiteSetting.title}\"")
      expect(plugin_outlet_debug).to have_github_link

      toolbar.toggle_plugin_outlets
      expect(plugin_outlet_debug).to have_no_outlets
    end

    it "shows wrapper outlet indicator" do
      visit("/latest")
      toolbar.enable
      toolbar.toggle_plugin_outlets

      expect(plugin_outlet_debug).to have_wrapper_outlet
    end
  end

  describe "block debugging" do
    it "shows block outlet boundaries with tooltip" do
      visit("/latest")
      toolbar.enable
      toolbar.toggle_block_outlet_boundaries

      expect(block_debug).to have_outlet_boundary
      block_debug.hover_outlet_badge
      expect(block_debug).to have_outlet_tooltip
      expect(block_debug).to have_outlet_github_link
    end

    context "with test theme blocks" do
      fab!(:theme) do
        theme_dir = "#{Rails.root}/spec/fixtures/themes/dev-tools-test-theme"
        theme = RemoteTheme.import_theme_from_directory(theme_dir)
        Theme.find(SiteSetting.default_theme_id).child_themes << theme
        theme
      end

      it "shows block visual overlay with tooltip" do
        visit("/latest")
        toolbar.enable
        toolbar.toggle_block_visual_overlay

        expect(block_debug).to have_block_info("theme:dev-tools-test:dev-tools-test-block")
        block_debug.hover_block_badge("theme:dev-tools-test:dev-tools-test-block")
        expect(block_debug).to have_block_tooltip
        expect(block_debug).to have_block_title("dev-tools-test-block")
        expect(block_debug).to have_block_outlet("hero-blocks")
        expect(block_debug).to have_block_arg(key: "title")
      end

      it "shows ghost blocks for failed conditions" do
        visit("/latest") # Anonymous user, admin condition fails
        toolbar.enable
        toolbar.toggle_block_visual_overlay

        expect(block_debug).to have_ghost_block("theme:dev-tools-test:dev-tools-conditional-block")
        block_debug.hover_ghost_badge("theme:dev-tools-test:dev-tools-conditional-block")
        expect(block_debug).to have_ghost_tooltip
        expect(block_debug).to have_conditions
      end

      it "shows block args values in tooltip" do
        visit("/latest")
        toolbar.enable
        toolbar.toggle_block_visual_overlay

        expect(block_debug).to have_block_info("theme:dev-tools-test:debug-args-block")
        block_debug.hover_block_badge("theme:dev-tools-test:debug-args-block")
        expect(block_debug).to have_block_tooltip
        expect(block_debug).to have_block_arg(key: "title")
        expect(block_debug).to have_block_arg(key: "count")
        expect(block_debug).to have_block_arg(key: "enabled")
      end

      it "shows ghost blocks with combined conditions" do
        visit("/latest") # Anonymous user, admin + TL2 condition fails
        toolbar.enable
        toolbar.toggle_block_visual_overlay

        expect(block_debug).to have_ghost_block("theme:dev-tools-test:debug-conditions-block")
        block_debug.hover_ghost_badge("theme:dev-tools-test:debug-conditions-block")
        expect(block_debug).to have_ghost_tooltip
        expect(block_debug).to have_conditions
      end

      it "shows nested ghost blocks for groups with all children hidden (4 levels deep)" do
        visit("/latest") # Anonymous user, all nested children fail admin condition
        toolbar.enable
        toolbar.toggle_block_visual_overlay

        # The outermost group should appear as a ghost since all its children are hidden
        expect(block_debug).to have_ghost_block("group")

        # Verify all 4 levels of nested groups appear as ghosts
        expect(page).to have_css(".block-debug-ghost[data-block-name='group']", minimum: 4)

        # The leaf block should also appear as a ghost
        expect(block_debug).to have_ghost_block("theme:dev-tools-test:nested-ghost-leaf-block")
      end

      it "reactively shows and hides overlays when toggling without page refresh" do
        visit("/latest")
        toolbar.enable

        # Initially no overlays
        expect(block_debug).to have_no_block_info
        expect(block_debug).to have_no_ghost_block

        # Enable visual overlay - should appear without page refresh
        toolbar.toggle_block_visual_overlay
        expect(block_debug).to have_block_info("theme:dev-tools-test:dev-tools-test-block")
        expect(block_debug).to have_ghost_block("theme:dev-tools-test:dev-tools-conditional-block")

        # Disable visual overlay - should disappear without page refresh
        toolbar.toggle_block_visual_overlay
        expect(block_debug).to have_no_block_info
        expect(block_debug).to have_no_ghost_block

        # Re-enable to confirm reactivity works both ways
        toolbar.toggle_block_visual_overlay
        expect(block_debug).to have_block_info("theme:dev-tools-test:dev-tools-test-block")
        expect(block_debug).to have_ghost_block("theme:dev-tools-test:dev-tools-conditional-block")
      end
    end
  end
end
