# frozen_string_literal: true

module DiscourseWireframe
  module PluginSetup
    module Access
      def self.apply(plugin)
        plugin.after_initialize do
          plugin.add_to_serializer(:current_user, :can_use_wireframe) do
            scope.user.staff? || scope.user.in_any_groups?(SiteSetting.wireframe_allowed_groups_map)
          end
        end
      end
    end
  end
end
