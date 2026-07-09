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
      path = Rails.root.join("app/assets/stylesheets/mobile.scss")

      expect(watcher.path_data(path.to_s, [])).to include(target: "mobile", plugin_name: nil)
    end

    it "infers special core targets from top-level filenames" do
      path = Rails.root.join("app/assets/stylesheets/color_definitions.scss")

      expect(watcher.path_data(path.to_s, [])).to include(
        target: "color_definitions",
        plugin_name: nil,
      )
    end
  end
end
