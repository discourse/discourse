# frozen_string_literal: true

module DiscourseWorkflows
  module SubmissionCheck
    class Runner
      GENERIC_ERROR = "discourse_workflows.errors.submission_check.unavailable"

      def self.check(post:, opts: {})
        return if !SiteSetting.enable_discourse_workflows || opts[:skip_validations]
        return if post.post_type.present? && post.post_type != ::Post.types[:regular]

        topic = post.topic || ::Topic.find_by(id: post.topic_id)
        return if topic&.private_message? || opts[:archetype] == Archetype.private_message
        return if topic.nil? && post.topic_id.present?

        category_id =
          if topic
            topic.category_id
          elsif opts[:shared_draft]
            SiteSetting.shared_drafts_category.to_i
          else
            opts[:category].presence&.to_i || SiteSetting.uncategorized_category_id
          end
        user = post.user
        return if user.nil?

        triggers = WorkflowDependency.cached_published_triggers(Graph::TRIGGER)
        return if triggers.empty?

        versions =
          WorkflowVersion.where(version_id: triggers.map(&:workflow_version_id)).index_by(
            &:version_id
          )
        workflows = Workflow.where(id: triggers.map(&:workflow_id)).index_by(&:id)

        budget = SandboxBudget.new(budget_ms: 500)
        triggers.each do |trigger|
          workflow = workflows[trigger.workflow_id]
          next unless workflow&.active_version_id == trigger.workflow_version_id
          cached_parameters = Graph.validate_scope!(trigger.trigger_node["parameters"])
          next unless category_matches?(cached_parameters, category_id)

          version = versions[trigger.workflow_version_id]
          raise Graph::Invalid unless version&.workflow_id == workflow.id
          trigger_node = version.nodes.find { |node| node["id"] == trigger.trigger_node_id }
          raise Graph::Invalid unless trigger_node&.dig("type") == Graph::TRIGGER
          parameters = Graph.validate_scope!(trigger_node["parameters"])
          next unless category_matches?(parameters, category_id)

          graph =
            Graph.new(
              nodes: version.nodes,
              connections: version.connections,
              settings: version.settings,
            ).validate!
          raise Graph::Invalid unless graph.trigger["id"] == trigger.trigger_node_id

          payload = {
            "submission" => {
              "kind" => topic ? "reply" : "topic",
              "is_reply" => topic.present?,
              "raw" => post.raw,
              "title" => topic ? topic.title : opts[:title],
              "category_id" => category_id,
            },
            "user" => {
              "id" => user.id,
              "trust_level" => user.trust_level,
              "staff" => user.staff?,
            },
            "topic" =>
              (
                if topic
                  {
                    "id" => topic.id,
                    "user_id" => topic.user_id,
                    "category_id" => topic.category_id,
                  }
                else
                  nil
                end
              ),
          }
          message = new(graph, payload, budget: budget).rejection
          return message if message
        rescue => error
          Rails.logger.warn(
            "discourse-workflows: submission check failed for workflow #{trigger.workflow_id}: #{error.class}",
          )
          return I18n.t(GENERIC_ERROR)
        end
        nil
      end

      def self.category_matches?(parameters, category_id)
        ids = parameters.fetch("category_ids", []).map(&:to_i)
        return true if ids.empty?
        return false if category_id.nil?
        return ids.include?(category_id) if parameters.fetch("include_subcategories", true) == false

        Nodes::BeforePostSubmission::V1.expand_subcategory_ids(ids).include?(category_id)
      end

      def initialize(graph, payload, budget:)
        @graph = graph
        @payload = payload
        @budget = budget
      end

      def rejection
        context = { "$json" => @payload, "__input_item" => { "json" => @payload } }
        sandbox = JsSandbox.new(context, vars: {}, budget_tracker: @budget)
        resolver = ExpressionResolver.new(context, sandbox: sandbox)
        names = @graph.edges[@graph.trigger["name"]][0].dup
        seen = Set.new
        until names.empty?
          name = names.shift
          next unless seen.add?(name)
          raise Graph::Invalid if seen.size > Graph::MAX_NODES
          node = @graph.node(name)
          return node.dig("parameters", "message") if node["type"] == Graph::REJECT

          parameters = node["parameters"]
          result =
            Executor::FilterParameter.execute_filter(
              parameters.fetch("conditions"),
              parameters.fetch("combinator", "and"),
              parameters.fetch("options", {}),
              resolver,
            )
          raise Graph::Invalid if resolver.expression_errors.present?
          names.concat(@graph.edges[node["name"]][result["passed"] ? 0 : 1])
        end
        nil
      ensure
        resolver&.dispose
        sandbox&.dispose
      end
    end
  end
end
