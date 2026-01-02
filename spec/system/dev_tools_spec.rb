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

        expect(block_debug).to have_block_info("dev-tools-test-block")
        block_debug.hover_block_badge("dev-tools-test-block")
        expect(block_debug).to have_block_tooltip
        expect(block_debug).to have_block_title("dev-tools-test-block")
        expect(block_debug).to have_block_outlet("hero-blocks")
        expect(block_debug).to have_block_arg(key: "title")
      end

      it "shows ghost blocks for failed conditions" do
        visit("/latest") # Anonymous user, admin condition fails
        toolbar.enable
        toolbar.toggle_block_visual_overlay

        expect(block_debug).to have_ghost_block("dev-tools-conditional-block")
        block_debug.hover_ghost_badge("dev-tools-conditional-block")
        expect(block_debug).to have_ghost_tooltip
        expect(block_debug).to have_conditions
      end
    end
  end
end
