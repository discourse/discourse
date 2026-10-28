# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeType do
  describe ".deprecation" do
    it "deprecates the versions superseded by a breaking output change" do
      deprecated =
        DiscourseWorkflows::Registry.nodes(include_disabled_plugins: true).select(&:deprecated?)

      expect(deprecated.map(&:name)).to contain_exactly(
        "DiscourseWorkflows::Nodes::Assigned::V1",
        "DiscourseWorkflows::Nodes::Badge::V1",
        "DiscourseWorkflows::Nodes::CardMoved::V1",
        "DiscourseWorkflows::Nodes::Group::V1",
        "DiscourseWorkflows::Nodes::PostDestroyed::V1",
        "DiscourseWorkflows::Nodes::PostEdited::V1",
        "DiscourseWorkflows::Nodes::PostLike::V1",
        "DiscourseWorkflows::Nodes::PostLike::V2",
        "DiscourseWorkflows::Nodes::PostLikeChanged::V1",
        "DiscourseWorkflows::Nodes::PostReactionChanged::V1",
        "DiscourseWorkflows::Nodes::PostRecovered::V1",
        "DiscourseWorkflows::Nodes::Topic::V1",
        "DiscourseWorkflows::Nodes::TopicModeration::V1",
        "DiscourseWorkflows::Nodes::TopicPin::V1",
        "DiscourseWorkflows::Nodes::TopicReceivedVote::V1",
        "DiscourseWorkflows::Nodes::Unassigned::V1",
      )
    end

    it "points every deprecated version to registered, non-deprecated successors" do
      DiscourseWorkflows::Registry
        .nodes(include_disabled_plugins: true)
        .select(&:deprecated?)
        .each do |node_class|
          deprecation = node_class.deprecation
          successors =
            Array(deprecation[:replaced_by]).map do |identifier|
              [
                identifier,
                DiscourseWorkflows::Registry.latest_node_type(
                  identifier,
                  include_disabled_plugins: true,
                ),
              ]
            end
          if deprecation[:superseded_by]
            successors << [
              "#{node_class.identifier} #{deprecation[:superseded_by]}",
              DiscourseWorkflows::Registry.find_node_type(
                node_class.identifier,
                version: deprecation[:superseded_by],
                include_disabled_plugins: true,
              ),
            ]
          end

          expect(successors).to be_present, "#{node_class.name} has no successor"
          successors.each do |label, successor|
            expect(successor).to be_present, "#{node_class.name}: #{label} isn't registered"
            expect(successor).not_to be_deprecated, "#{node_class.name}: #{label} is deprecated"
          end
        end
    end
  end
end
