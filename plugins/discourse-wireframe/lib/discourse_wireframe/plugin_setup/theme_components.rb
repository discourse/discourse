# frozen_string_literal: true

module DiscourseWireframe
  module PluginSetup
    module ThemeComponents
      def self.apply(plugin)
        plugin.register_managed_theme_components do
          DiscourseWireframe::BlockLayoutCompanion.pluck(:component_theme_id)
        end
      end
    end
  end
end
