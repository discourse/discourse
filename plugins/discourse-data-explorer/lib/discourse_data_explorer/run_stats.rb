# frozen_string_literal: true

module DiscourseDataExplorer
  # A stand-in "official plugin" living inside the spike: it attaches run
  # statistics to queries through the Kit's plugin surface exactly as a
  # separate plugin's `jsonapi` block would (docs/plugins-design.md B/D), and
  # gives the generated docs a real plugin to document
  # (docs/api-docs-generation.md §8). Own timeline — not in CORE_PLUGINS.
  module RunStats
    NAMESPACE = "run-stats"

    Stats = Data.define(:id, :stale)

    class StatsResource < JsonApiKit::ApplicationResource
      type :"run-stats"
      description "Run statistics the run-stats plugin attaches to queries."

      attribute :stale,
                :boolean,
                description: "Whether the query has never been run.",
                example: false
    end

    class RenameOutdatedToStale < JsonApiKit::VersionChange
      version "2026-06-20"
      description "Renames the run-stats `outdated` attribute to `stale`."

      resource :"run-stats" do
        renamed_attribute from: :outdated, to: :stale
        renamed_filter from: :outdated, to: :stale
      end
    end

    class << self
      # Declares through the plugin.rb `jsonapi` keyword — the real registration
      # path. Idempotent: `after_initialize` runs once per boot, but the Kit
      # registry is process-lifetime state, so dev reloads may re-enter (spike
      # trade-off).
      def register!(plugin = Discourse.plugins_by_name["discourse-data-explorer"])
        return if JsonApiKit.plugins.key?(NAMESPACE)

        plugin.jsonapi(namespace: NAMESPACE) do
          register_relationship(
            :queries,
            resource: StatsResource,
            description: "Run statistics the run-stats plugin attaches to the query.",
          ) { |query| Stats.new(id: query.id, stale: query.last_run_at.nil?) }

          register_filter(
            :queries,
            :stale,
            :boolean,
            description: "Whether the query has never been run.",
          ) do |scope, value|
            value == "true" ? scope.where(last_run_at: nil) : scope.where.not(last_run_at: nil)
          end

          register_version_change(RenameOutdatedToStale)
        end
      end
    end
  end
end
