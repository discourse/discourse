# frozen_string_literal: true

module DiscourseAi
  module Agents
    module Tools
      # Lists the appearance changes saved on the site, so one can be made
      # live or switched back.
      class ListAppearanceChanges < Tool
        DEFAULT_LIMIT = 10
        MAX_LIMIT = 25

        def self.name
          "list_appearance_changes"
        end

        def self.signature
          {
            name:,
            description:
              "Lists the most recent appearance changes saved on this site, newest first, with whether each one is live.",
            parameters: [
              {
                name: "limit",
                type: "integer",
                description: "How many changes to list, up to #{MAX_LIMIT}",
              },
            ],
          }
        end

        def self.available_for_context?(context)
          AppearanceAuthoring.visible?(context&.user)
        end

        def invoke
          refusal = AppearanceAuthoring.denial(user: context.user, phase: :generation)
          return error_response(refusal) if refusal

          limit = (parameters[:limit].presence || DEFAULT_LIMIT).to_i.clamp(1, MAX_LIMIT)
          appearance_changes =
            AppearanceChange
              .includes(:theme, :light_color_scheme, :dark_color_scheme)
              .order(id: :desc)
              .limit(limit)

          { appearance_changes: appearance_changes.map { |change| describe(change) } }
        end

        private

        def describe(appearance_change)
          status = AppearanceAuthoring.status(appearance_change)

          {
            id: appearance_change.id,
            name: appearance_change.name,
            kind: appearance_change.kind,
            status:,
            theme: appearance_change.theme.name,
            saved_at: appearance_change.created_at.iso8601,
            preview_url: (AppearanceAuthoring.preview_url(appearance_change) if status != "live"),
          }.compact
        end
      end
    end
  end
end
