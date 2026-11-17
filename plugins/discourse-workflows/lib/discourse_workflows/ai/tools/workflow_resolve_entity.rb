# frozen_string_literal: true

module DiscourseWorkflows
  module Ai
    module Tools
      class WorkflowResolveEntity < Base
        SUPPORTED_KINDS = %w[
          category
          tag
          tag_group
          user
          group
          badge
          data_table
          topic
          node_option
        ].freeze
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
                description: "Name, slug, username, topic id, or partial text to search for",
                type: "string",
                required: true,
              },
              {
                name: "node_type",
                description:
                  "For node_option: the node identifier whose setting declares type_options.load_options_method, e.g. trigger:reviewable_created",
                type: "string",
              },
              {
                name: "method",
                description: "For node_option: the setting's type_options.load_options_method",
                type: "string",
              },
              {
                name: "node_parameters",
                description:
                  "For node_option: the node's other settings, for option lists that depend on them (type_options.load_options_depends_on)",
                type: "object",
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

        def resolve_tag_group(query)
          ::TagGroup
            .where("name ILIKE ?", "%#{::TagGroup.sanitize_sql_like(query)}%")
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

        def resolve_topic(query)
          scope = Topic.listable_topics
          scope =
            if query.match?(/\A\d+\z/)
              scope.where(id: query.to_i)
            else
              scope.where("title ILIKE ?", "%#{Topic.sanitize_sql_like(query)}%")
            end

          scope
            .order(bumped_at: :desc)
            .limit(MAX_RESULTS)
            .pluck(:id, :title, :slug)
            .map { |id, title, slug| { id: id, title: title, slug: slug } }
        end

        def resolve_data_table(query)
          DiscourseWorkflows::DataTable
            .where("name ILIKE ?", "%#{DiscourseWorkflows::DataTable.sanitize_sql_like(query)}%")
            .order(:name)
            .limit(MAX_RESULTS)
            .pluck(:id, :name)
            .map { |id, name| { id: id, name: name } }
        end

        # Any option list a node loads in the editor, so the AI can fill settings the other kinds don't cover.
        def resolve_node_option(query)
          node_class = DiscourseWorkflows::Registry.latest_node_type(parameters[:node_type].to_s)
          return [] if !node_class.respond_to?(:load_options_context)

          options_context =
            DiscourseWorkflows::LoadOptionsContext.new(
              method_name: parameters[:method],
              parameters: parameters[:node_parameters].presence || {},
              filter: query,
              node_class:,
              user: context.user,
              guardian: context.user.guardian,
            )

          Array(node_class.load_options_context(options_context)).first(MAX_RESULTS)
        rescue Discourse::InvalidAccess
          # Loaders that need credentials can't run here: the AI has no node credentials to pass.
          []
        end
      end
    end
  end
end
