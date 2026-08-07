# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowResolveEntity < Base
        SUPPORTED_KINDS = %w[category tag user group badge data_table].freeze
        MAX_RESULTS = 10

        def self.signature
          {
            name: name,
            description:
              "Resolves Discourse entity names to IDs or names that can be used in workflow node parameters.",
            parameters: [
              {
                name: "kind",
                description: "One of: #{SUPPORTED_KINDS.join(", ")}",
                type: "string",
                required: true,
              },
              {
                name: "query",
                description: "Name, slug, username, or partial text to search for",
                type: "string",
                required: true,
              },
            ],
          }
        end

        def self.name
          "workflow_resolve_entity"
        end

        def invoke
          return not_allowed_response if !ensure_can_manage_workflows!

          kind = parameters[:kind].to_s
          query = parameters[:query].to_s.strip
          return error_response("Unsupported entity kind") if SUPPORTED_KINDS.exclude?(kind)
          return error_response("Query is required") if query.blank?

          { status: "success", kind: kind, matches: send("resolve_#{kind}", query) }
        end

        private

        def resolve_category(query)
          Category
            .where(
              "name ILIKE :query OR slug ILIKE :query",
              query: "%#{Category.sanitize_sql_like(query)}%",
            )
            .order(:name)
            .limit(MAX_RESULTS)
            .map { |category| { id: category.id, name: category.name, slug: category.slug } }
        end

        def resolve_tag(query)
          Tag
            .where("name ILIKE ?", "%#{Tag.sanitize_sql_like(query)}%")
            .order(:name)
            .limit(MAX_RESULTS)
            .pluck(:id, :name)
            .map { |id, name| { id: id, name: name } }
        end

        def resolve_user(query)
          User
            .real
            .where("username_lower LIKE ?", "%#{User.normalize_username(query)}%")
            .order(:username_lower)
            .limit(MAX_RESULTS)
            .pluck(:id, :username, :name)
            .map { |id, username, name| { id: id, username: username, name: name } }
        end

        def resolve_group(query)
          Group
            .where("name ILIKE ?", "%#{Group.sanitize_sql_like(query)}%")
            .order(:name)
            .limit(MAX_RESULTS)
            .pluck(:id, :name)
            .map { |id, name| { id: id, name: name } }
        end

        def resolve_badge(query)
          Badge
            .where(enabled: true)
            .where("name ILIKE ?", "%#{Badge.sanitize_sql_like(query)}%")
            .order(:name)
            .limit(MAX_RESULTS)
            .pluck(:id, :name)
            .map { |id, name| { id: id, name: name } }
        end

        def resolve_data_table(query)
          DiscourseWorkflows::DataTable
            .where("name ILIKE ?", "%#{DiscourseWorkflows::DataTable.sanitize_sql_like(query)}%")
            .order(:name)
            .limit(MAX_RESULTS)
            .pluck(:id, :name)
            .map { |id, name| { id: id, name: name } }
        end
      end
    end
  end
end
