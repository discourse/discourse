# frozen_string_literal: true

require "stylesheet/watcher"

RSpec.describe Stylesheet::Watcher do
  subject(:watcher) { described_class.new([]) }

  describe "#path_data" do
    it "does not infer a core target from the filename" do
      path =
        Rails.root.join("app/assets/stylesheets/common/components/admin-onboarding-banner.scss")

      expect(watcher.path_data(path.to_s, [])).to include(target: nil, plugin_name: nil)
    end

    it "infers core targets from stylesheet directories" do
      path = Rails.root.join("app/assets/stylesheets/admin/dashboard.scss")

      expect(watcher.path_data(path.to_s, [])).to include(target: "admin", plugin_name: nil)
    end

    it "infers core targets from top-level stylesheet filenames" do
      path = Rails.root.join("app/assets/stylesheets/wizard.scss")

      expect(watcher.path_data(path.to_s, [])).to include(target: "wizard", plugin_name: nil)
    end

    it "infers special core targets from top-level filenames" do
      path = Rails.root.join("app/assets/stylesheets/color_definitions.scss")

      expect(watcher.path_data(path.to_s, [])).to include(
        target: "color_definitions",
        plugin_name: nil,
      )
    end

    it "infers plugin names from stylesheet paths under plugins" do
      plugin_path = Rails.root.join("plugins/discourse-events").to_s
      path = Rails.root.join("plugins/discourse-events/assets/stylesheets/admin/calendar.scss")

      expect(watcher.path_data(path.to_s, [plugin_path])).to include(
        target: nil,
        plugin_name: "discourse-events",
      )
    end
  end

  describe "#plugin_assets_refresh" do
    let(:plugin_name) { "test-plugin" }
    let(:manager) { instance_double(Stylesheet::Manager) }

    before do
      DiscoursePluginRegistry.stylesheets[plugin_name] = Set.new(["stylesheets/common.scss"])
      DiscoursePluginRegistry.desktop_stylesheets[plugin_name] = Set.new(
        ["stylesheets/desktop.scss"],
      )
      DiscoursePluginRegistry.mobile_stylesheets[plugin_name] = Set.new(["stylesheets/mobile.scss"])
      DiscoursePluginRegistry.admin_stylesheets[plugin_name] = Set.new(["stylesheets/admin.scss"])

      allow(Stylesheet::Manager).to receive(:new).and_return(manager)
      allow(manager).to receive(:stylesheet_data) do |target|
        [{ target: target, new_href: "/stylesheets/#{target}.css" }]
      end
    end

    after { DiscoursePluginRegistry.reset! }

    it "publishes changes for every registered plugin target" do
      messages =
        MessageBus.track_publish("/file-change") { watcher.plugin_assets_refresh(plugin_name) }

      expect(messages.first.data).to contain_exactly(
        { target: :"test-plugin", new_href: "/stylesheets/test-plugin.css" },
        { target: :"test-plugin_desktop", new_href: "/stylesheets/test-plugin_desktop.css" },
        { target: :"test-plugin_mobile", new_href: "/stylesheets/test-plugin_mobile.css" },
        { target: :"test-plugin_admin", new_href: "/stylesheets/test-plugin_admin.css" },
      )
    end

    it "skips publishing when the plugin has no registered stylesheets" do
      DiscoursePluginRegistry.reset!

      messages =
        MessageBus.track_publish("/file-change") { watcher.plugin_assets_refresh(plugin_name) }

      expect(messages).to be_empty
    end
  end

  describe "#core_assets_refresh" do
    let(:manager) { instance_double(Stylesheet::Manager) }

    before do
      allow(Stylesheet::Manager).to receive(:new).and_return(manager)
      allow(manager).to receive(:stylesheet_data) do |target|
        [{ target: target, new_href: "/stylesheets/#{target}.css" }]
      end
      allow(manager).to receive(:color_scheme_stylesheet_details) do |id, **|
        { color_scheme_id: id, new_href: "/stylesheets/color_definitions_#{id}.css" }.freeze
      end
    end

    it "publishes fresh color scheme stylesheets for color definition changes" do
      scheme = Fabricate(:color_scheme, user_selectable: true)

      messages =
        MessageBus.track_publish("/file-change") do
          watcher.core_assets_refresh("color_definitions")
        end

      expect(messages.first.data.map { |m| m[:target] }.uniq).to eq(["color_definitions"])
      expect(messages.first.data.map { |m| m[:color_scheme_id] }).to include(scheme.id, nil)
    end

    it "publishes the default theme's color schemes" do
      scheme = Fabricate(:color_scheme)
      dark_scheme = Fabricate(:color_scheme)
      theme = Fabricate(:theme, color_scheme_id: scheme.id, dark_color_scheme_id: dark_scheme.id)
      theme.set_default!

      messages =
        MessageBus.track_publish("/file-change") do
          watcher.core_assets_refresh("color_definitions")
        end

      expect(messages.first.data.map { |m| m[:color_scheme_id] }).to include(
        scheme.id,
        dark_scheme.id,
      )
    end

    it "also refreshes color scheme stylesheets for changes without a target" do
      messages = MessageBus.track_publish("/file-change") { watcher.core_assets_refresh(nil) }

      targets = messages.flat_map(&:data).map { |m| m[:target] }
      expect(targets).to include(:admin, :common, "color_definitions")
    end

    it "does not refresh color scheme stylesheets for targeted changes" do
      allow(Stylesheet::Manager).to receive(:clear_color_scheme_cache!)

      MessageBus.track_publish("/file-change") { watcher.core_assets_refresh("admin") }

      expect(Stylesheet::Manager).not_to have_received(:clear_color_scheme_cache!)
    end
  end
end
