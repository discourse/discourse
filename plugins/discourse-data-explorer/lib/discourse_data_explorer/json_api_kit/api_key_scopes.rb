# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # Plugs the Kit into core's API key scope system (docs/resource-design.md §8).
    # Core's model, matcher and admin UI are untouched: we only produce the mapping
    # hash they already understand.
    #
    # Scopes gate ROUTES, not documents, so the mapping is derived per endpoint from
    # the route table rather than declared on the resource: one resource type can be
    # served by several routes at different privilege, and only the routes know which
    # actions exist. Deriving from the route table (instead of `BaseController
    # .descendants`) also means a new endpoint is scoped as soon as it is routed —
    # nothing to declare, nothing to forget, and no dependency on eager loading.
    module ApiKeyScopes
      # `index`/`show` share `read`; each write keeps its own scope, so a key can be
      # granted exactly the verbs it needs.
      SCOPE_ACTIONS = {
        "index" => :read,
        "show" => :read,
        "create" => :create,
        "update" => :update,
        "destroy" => :delete,
      }.freeze

      # Member routes carry an id, so core's `allowed_parameters` can restrict a key
      # to specific records. NB (same as core's id-restricted scopes): a listing
      # carries no id, so restricting ids also refuses the listing.
      MEMBER_ACTIONS = %w[show update destroy].freeze

      class << self
        # Called from the plugin's routes file, right after the Kit's routes are
        # drawn: plugin `after_initialize` runs BEFORE Rails loads the route table
        # (verified — it is empty there), so registering from there would derive
        # nothing. Registering where the routes are declared also keeps the two facts
        # together. In the real phase this is what a `jsonapi_resources` route helper
        # would do as it draws them.
        def register!(plugin = Discourse.plugins_by_name[PLUGIN_NAME])
          reset!
          mappings.each do |resource, actions|
            DiscoursePluginRegistry.register_api_key_scope_mapping({ resource => actions }, plugin)
          end
        end

        # `resource:action`, the scope a caller needs for this endpoint action —
        # the same pair the admin UI shows. Consumed by the docs generator.
        def scope_name(controller_class, action)
          scope_action = scope_action_for(controller_class, action) or return
          "#{controller_class.api_scope_resource}:#{scope_action}"
        end

        # The controller's grouping wins when it declares one (`api_scopes`), so an
        # endpoint that needs a coarser or different split says so once.
        def scope_action_for(controller_class, action)
          groups = controller_class.api_scope_groups
          if groups.present?
            return groups.find { |_, actions| actions.include?(action.to_sym) }&.first
          end
          SCOPE_ACTIONS[action.to_s]
        end

        # Memoized: `ApiKeyScope.scope_mappings` runs on every request made with a
        # granular key, so walking the route table there would be paid per request.
        def mappings
          @mappings ||= build
        end

        def reset! = @mappings = nil

        private

        def build
          kit_routes.each_with_object({}) do |(controller, action), mappings|
            klass = controller_class(controller)
            scope_action = scope_action_for(klass, action) or next
            resource = klass.api_scope_resource
            entry = ((mappings[resource] ||= {})[scope_action] ||= { actions: [] })
            entry[:actions] |= ["#{controller}##{action}"]
            entry[:params] = %i[id] if MEMBER_ACTIONS.include?(action)
          end
        end

        def kit_routes
          Rails
            .application
            .routes
            .routes
            .filter_map do |route|
              controller = route.defaults[:controller]
              action = route.defaults[:action]
              next if controller.blank? || action.blank?
              # The Kit's namespace: cheap to test, and it keeps us from
              # constantizing every controller in the route table. The real-phase
              # answer is a route helper that records its endpoints as it draws them.
              next if !controller.include?("json_api_kit")
              next if !kit_controller?(controller)
              [controller, action]
            end
            .uniq
        end

        # Internal endpoints grant no scope: they are not part of the published
        # surface, and once they stop accepting API keys entirely there would be
        # nothing left to scope (docs/resource-design.md §9).
        def kit_controller?(controller)
          klass = controller_class(controller)
          klass.present? && klass < BaseController && !klass.internal?
        end

        def controller_class(controller)
          "#{controller}_controller".camelize.safe_constantize
        end
      end
    end
  end
end
