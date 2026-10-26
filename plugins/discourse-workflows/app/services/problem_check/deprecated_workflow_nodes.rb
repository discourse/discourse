# frozen_string_literal: true

class ProblemCheck::DeprecatedWorkflowNodes < ProblemCheck
  self.priority = "low"

  def call
    return no_problem if !SiteSetting.enable_discourse_workflows
    return no_problem if workflows.empty?

    problem
  end

  private

  def translation_data
    { workflows_list: }
  end

  def workflows
    @workflows ||=
      if deprecated_identifiers.empty?
        []
      else
        candidate_workflows.select do |workflow|
          (workflow.nodes + workflow.published_nodes).any? do |node|
            DiscourseWorkflows::NodeData.node_type(node)&.deprecated?
          end
        end
      end
  end

  # Dependency rows only know a node's identifier, not its version, so they
  # narrow the scan to workflows that may hold a deprecated version.
  def candidate_workflows
    DiscourseWorkflows::Workflow
      .where(
        id:
          DiscourseWorkflows::WorkflowDependency.workflows_referencing(
            "node_type",
            deprecated_identifiers,
          ),
      )
      .includes(:active_version)
      .order(:name)
  end

  def deprecated_identifiers
    @deprecated_identifiers ||=
      DiscourseWorkflows::Registry.nodes.select(&:deprecated?).map(&:identifier).uniq
  end

  def workflows_list
    items =
      workflows.map do |workflow|
        url = "#{Discourse.base_path}/admin/plugins/discourse-workflows/workflows/#{workflow.id}"
        "<li><a href=\"#{url}\">#{CGI.escapeHTML(workflow.name)}</a></li>"
      end

    "<ul>#{items.join}</ul>"
  end
end
