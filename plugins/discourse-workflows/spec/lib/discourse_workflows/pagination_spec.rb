# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Pagination do
  describe ".normalize_limit" do
    it "defaults blank limits and clamps out-of-range values" do
      expect(described_class.normalize_limit(nil)).to eq(described_class::DEFAULT_LIMIT)
      expect(described_class.normalize_limit(0)).to eq(1)
      expect(described_class.normalize_limit(999)).to eq(described_class::MAX_LIMIT)
    end
  end

  describe ".cursor_page" do
    fab!(:first_variable) { Fabricate(:discourse_workflows_variable, key: "FIRST") }
    fab!(:second_variable) { Fabricate(:discourse_workflows_variable, key: "SECOND") }
    fab!(:third_variable) { Fabricate(:discourse_workflows_variable, key: "THIRD") }

    let(:scope) { DiscourseWorkflows::Variable.order(id: :desc) }

    it "returns records, total rows, and a cursor URL when more records exist" do
      page =
        described_class.cursor_page(
          scope: scope,
          cursor: nil,
          limit: 2,
          path: "/admin/plugins/discourse-workflows/variables.json",
        )

      expect(page.records.map(&:id)).to eq([third_variable.id, second_variable.id])
      expect(page.total_rows).to eq(3)
      expect(page.load_more_url).to eq(
        "/admin/plugins/discourse-workflows/variables.json?cursor=#{second_variable.id}&limit=2",
      )
    end

    it "applies the cursor and keeps query params in the next URL" do
      page =
        described_class.cursor_page(
          scope: scope,
          cursor: third_variable.id,
          limit: 1,
          path: "/admin/plugins/discourse-workflows/variables.json",
          query: {
            filter: "active",
          },
        )

      expect(page.records.map(&:id)).to eq([second_variable.id])
      expect(page.load_more_url).to start_with("/admin/plugins/discourse-workflows/variables.json?")
      expect(page.load_more_url).to include(
        "cursor=#{second_variable.id}",
        "filter=active",
        "limit=1",
      )
    end

    it "omits the cursor URL when all matching records fit" do
      page =
        described_class.cursor_page(
          scope: scope,
          cursor: second_variable.id,
          limit: 2,
          path: "/admin/plugins/discourse-workflows/variables.json",
        )

      expect(page.records.map(&:id)).to eq([first_variable.id])
      expect(page.load_more_url).to be_nil
    end
  end

  describe ".cursor_page with a custom column" do
    fab!(:workflow, :discourse_workflows_workflow)

    before do
      workflow.snapshot!(user: workflow.created_by) # version 2
      workflow.snapshot!(user: workflow.created_by) # version 3
    end

    let(:scope) { workflow.workflow_versions.order(version_number: :desc) }

    it "paginates and builds the cursor URL using the given column" do
      page =
        described_class.cursor_page(
          scope: scope,
          cursor: nil,
          limit: 2,
          path: "/versions.json",
          column: :version_number,
        )

      expect(page.records.map(&:version_number)).to eq([3, 2])
      expect(page.total_rows).to eq(3)
      expect(page.load_more_url).to eq("/versions.json?cursor=2&limit=2")
    end

    it "applies the cursor using the given column" do
      page =
        described_class.cursor_page(
          scope: scope,
          cursor: 2,
          limit: 10,
          path: "/versions.json",
          column: :version_number,
        )

      expect(page.records.map(&:version_number)).to eq([1])
      expect(page.load_more_url).to be_nil
    end
  end
end
