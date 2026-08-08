# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::WorkflowTag do
  fab!(:workflow, :discourse_workflows_workflow)

  describe ".normalize_all" do
    it "strips, downcases, collapses whitespace, drops blanks, and dedupes" do
      expect(described_class.normalize_all([" Ops ", "OPS", "a  \t b", "", nil, "billing"])).to eq(
        %w[ops a\ b billing],
      )
    end

    it "returns an empty array for nil" do
      expect(described_class.normalize_all(nil)).to eq([])
    end
  end

  describe ".resolve_or_create!" do
    it "creates missing tags and reuses existing ones" do
      existing = Fabricate(:discourse_workflows_workflow_tag, name: "ops")

      tags = described_class.resolve_or_create!(%w[ops billing])

      expect(tags.map(&:name)).to contain_exactly("ops", "billing")
      expect(tags.find { |tag| tag.name == "ops" }.id).to eq(existing.id)
      expect(described_class.count).to eq(2)
    end

    it "does not create duplicates when called twice with the same names" do
      2.times { described_class.resolve_or_create!(%w[ops]) }

      expect(described_class.where(name: "ops").count).to eq(1)
    end
  end

  describe ".sync!" do
    fab!(:other_workflow, :discourse_workflows_workflow)

    it "assigns the given tags to the workflow" do
      described_class.sync!(workflow:, names: ["Ops", " billing "])

      expect(workflow.tags.map(&:name)).to eq(%w[billing ops])
    end

    it "removes tags no longer present and prunes orphans" do
      described_class.sync!(workflow:, names: %w[ops billing])
      described_class.sync!(workflow:, names: %w[billing])

      expect(workflow.tags.map(&:name)).to eq(%w[billing])
      expect(described_class.exists?(name: "ops")).to eq(false)
    end

    it "keeps a removed tag that is still used by another workflow" do
      described_class.sync!(workflow:, names: %w[ops])
      described_class.sync!(workflow: other_workflow, names: %w[ops])
      described_class.sync!(workflow:, names: [])

      expect(workflow.tags).to be_empty
      expect(other_workflow.tags.map(&:name)).to eq(%w[ops])
      expect(described_class.exists?(name: "ops")).to eq(true)
    end
  end

  describe ".prune!" do
    it "only deletes tags with no remaining mappings" do
      mapped = Fabricate(:discourse_workflows_workflow_tag, name: "mapped")
      orphan = Fabricate(:discourse_workflows_workflow_tag, name: "orphan")
      DiscourseWorkflows::WorkflowTagMapping.create!(workflow:, workflow_tag: mapped)

      described_class.prune!([mapped.id, orphan.id])

      expect(described_class.pluck(:name)).to eq(%w[mapped])
    end
  end
end
