# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::ReviewableApproved::V1 do
  fab!(:reviewable, :reviewable_flagged_post)

  describe ".property_schema" do
    it "includes reviewable type options for the multi-select control" do
      expect(described_class.property_schema.dig(:reviewable_types, :options)).to include(
        { value: "ReviewableFlaggedPost", label: "Reviewable flagged post" },
      )
    end
  end

  describe ".load_options_context" do
    it "returns core and plugin reviewable types" do
      plugin_instance = Plugin::Instance.new
      plugin_reviewable_type =
        Class.new(Reviewable) do
          def self.name
            "CustomReviewableType"
          end
        end

      plugin_instance.register_reviewable_type(plugin_reviewable_type)

      context =
        DiscourseWorkflows::LoadOptionsContext.new(
          method_name: "reviewable_types",
          filter: "reviewable",
        )

      expect(described_class.load_options_context(context)).to include(
        { id: "ReviewableFlaggedPost", name: "Reviewable flagged post" },
        { id: "CustomReviewableType", name: "Custom reviewable type" },
      )
    ensure
      DiscoursePluginRegistry._raw_reviewable_types.reject! do |entry|
        entry[:value] == plugin_reviewable_type
      end
    end
  end

  describe "#output" do
    it "returns reviewable data", :aggregate_failures do
      moderator = Fabricate(:moderator)
      reviewable.update!(status: :approved)
      output = described_class.new(:approved, reviewable, acting_user: moderator).output

      expect(output[:reviewable]).to include(status: "approved")
      expect(output[:actor]).to include(id: moderator.id, username: moderator.username)
      expect(output).to match_node_output_schema(described_class)
    end
  end
end
