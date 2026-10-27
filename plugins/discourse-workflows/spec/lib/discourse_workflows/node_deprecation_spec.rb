# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType do
  describe ".deprecation" do
    it "deprecates the versions superseded by a breaking output change" do
      deprecated =
        DiscourseWorkflows::Registry.nodes(include_disabled_plugins: true).select(&:deprecated?)

      expect(deprecated.map(&:name)).to contain_exactly(
        "DiscourseWorkflows::Nodes::Assigned::V1",
        "DiscourseWorkflows::Nodes::CardMoved::V1",
        "DiscourseWorkflows::Nodes::PostDestroyed::V1",
        "DiscourseWorkflows::Nodes::PostEdited::V1",
        "DiscourseWorkflows::Nodes::PostLike::V1",
        "DiscourseWorkflows::Nodes::PostLikeChanged::V1",
        "DiscourseWorkflows::Nodes::PostReactionChanged::V1",
        "DiscourseWorkflows::Nodes::PostRecovered::V1",
        "DiscourseWorkflows::Nodes::Topic::V1",
        "DiscourseWorkflows::Nodes::TopicReceivedVote::V1",
        "DiscourseWorkflows::Nodes::Unassigned::V1",
      )
    end

    it "points every deprecated version to a registered, non-deprecated successor" do
      DiscourseWorkflows::Registry
        .nodes(include_disabled_plugins: true)
        .select(&:deprecated?)
        .each do |node_class|
          successor =
            DiscourseWorkflows::Registry.find_node_type(
              node_class.identifier,
              version: node_class.deprecation[:superseded_by],
              include_disabled_plugins: true,
            )

          expect(successor).to be_present, "#{node_class.name} has no registered successor"
          expect(successor).not_to be_deprecated, "#{successor.name} is deprecated"
        end
    end
  end
end
