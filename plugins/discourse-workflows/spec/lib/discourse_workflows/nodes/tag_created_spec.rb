# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TagCreated::V1 do
  fab!(:tag) { Fabricate(:tag, name: "workflow-tag") }

  describe "#valid?" do
    it "returns true when the tag exists" do
      expect(described_class.new(tag)).to be_valid
    end

    it "returns false when the tag is missing" do
      expect(described_class.new(nil)).not_to be_valid
    end
  end

  describe "#output" do
    it "returns the tag payload", :aggregate_failures do
      tag.update_columns(description: "A workflow tag", description_cooked: "<p>A workflow tag</p>")

      output = described_class.new(tag).output

      expect(output[:tag]).to include(
        id: tag.id,
        name: tag.name,
        slug: tag.slug,
        topic_count: tag.staff_topic_count,
        staff: false,
        description: tag.description,
        description_cooked: tag.description_cooked,
      )
      expect(output).to match_node_output_schema(described_class)
    end

    it "outputs whoever created the tag as actor, null when the code didn't say" do
      admin = Fabricate(:admin)

      event = DiscourseEvent.track(:tag_created) { Fabricate(:tag, created_by: admin) }

      expect(described_class.new(*event[:params]).output[:actor]).to include(id: admin.id)
      expect(described_class.new(tag).output[:actor]).to be_nil
    end
  end
end
