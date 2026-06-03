# frozen_string_literal: true

describe AdminDashboardSectionConfiguration do
  fab!(:admin)

  describe ".sections" do
    it "seeds every known section, all visible, in canonical order on an empty table" do
      expect(described_class.sections).to eq(
        [
          { id: "highlights", visible: true },
          { id: "reports", visible: true },
          { id: "traffic", visible: true },
          { id: "engagement", visible: true },
        ],
      )
    end

    it "is idempotent and does not duplicate rows across reads" do
      described_class.sections
      described_class.sections

      expect(AdminDashboardSection.count).to eq(described_class::KNOWN_SECTIONS.size)
    end

    it "keeps each section's stored position, independent of visibility" do
      described_class.update(
        [
          { id: "highlights", visible: false },
          { id: "reports", visible: true },
          { id: "traffic", visible: true },
          { id: "engagement", visible: true },
        ],
        actor: admin,
      )

      # highlights is hidden but must stay in first position
      expect(described_class.sections).to eq(
        [
          { id: "highlights", visible: false },
          { id: "reports", visible: true },
          { id: "traffic", visible: true },
          { id: "engagement", visible: true },
        ],
      )
    end

    it "auto-seeds a newly-introduced known section at the end" do
      AdminDashboardSection.where(section_id: "engagement").delete_all

      sections = described_class.sections
      expect(sections.map { |s| s[:id] }).to eq(described_class::KNOWN_SECTIONS)
      expect(sections.last).to eq({ id: "engagement", visible: true })
    end
  end

  describe ".visible_section_ids" do
    it "returns only visible sections, in stored order" do
      described_class.update(
        [
          { id: "reports", visible: true },
          { id: "highlights", visible: false },
          { id: "engagement", visible: true },
          { id: "traffic", visible: false },
        ],
        actor: admin,
      )

      expect(described_class.visible_section_ids).to eq(%w[reports engagement])
    end
  end

  describe ".update" do
    it "round-trips order and visibility" do
      described_class.update(
        [
          { id: "engagement", visible: true },
          { id: "highlights", visible: false },
          { id: "reports", visible: true },
          { id: "traffic", visible: true },
        ],
        actor: admin,
      )

      expect(described_class.sections).to eq(
        [
          { id: "engagement", visible: true },
          { id: "highlights", visible: false },
          { id: "reports", visible: true },
          { id: "traffic", visible: true },
        ],
      )
    end

    it "toggling a section off then on leaves its position unchanged" do
      off = described_class.sections.map { |s| s[:id] == "reports" ? s.merge(visible: false) : s }
      described_class.update(off, actor: admin)

      on = described_class.sections.map { |s| s[:id] == "reports" ? s.merge(visible: true) : s }
      described_class.update(on, actor: admin)

      expect(described_class.sections).to eq(
        [
          { id: "highlights", visible: true },
          { id: "reports", visible: true },
          { id: "traffic", visible: true },
          { id: "engagement", visible: true },
        ],
      )
    end

    it "coerces non-boolean visible values" do
      described_class.update(
        [
          { id: "highlights", visible: "true" },
          { id: "reports", visible: "false" },
          { id: "engagement", visible: 1 },
          { id: "traffic", visible: 0 },
        ],
        actor: admin,
      )

      expect(described_class.visible_section_ids).to eq(%w[highlights engagement])
    end

    it "drops unknown section ids" do
      described_class.update(
        [{ id: "frobnitz", visible: true }, { id: "highlights", visible: true }],
        actor: admin,
      )

      expect(described_class.sections.map { |s| s[:id] }).to match_array(
        described_class::KNOWN_SECTIONS,
      )
    end

    it "appends known sections missing from the input, preserving their visibility" do
      described_class.update([{ id: "reports", visible: false }], actor: admin)

      sections = described_class.sections
      expect(sections.first).to eq({ id: "reports", visible: false })
      expect(sections.map { |s| s[:id] }).to match_array(described_class::KNOWN_SECTIONS)
    end

    it "accepts string keys as well as symbols" do
      described_class.update(
        [{ "id" => "reports", "visible" => true }, { "id" => "highlights", "visible" => false }],
        actor: admin,
      )

      expect(described_class.sections.first(2)).to eq(
        [{ id: "reports", visible: true }, { id: "highlights", visible: false }],
      )
    end

    it "logs a custom staff action" do
      expect {
        described_class.update([{ id: "highlights", visible: false }], actor: admin)
      }.to change { UserHistory.where(custom_type: "update_dashboard_sections").count }.by(1)
    end

    it "returns the new sections snapshot" do
      result =
        described_class.update(
          [
            { id: "engagement", visible: true },
            { id: "highlights", visible: true },
            { id: "reports", visible: true },
            { id: "traffic", visible: true },
          ],
          actor: admin,
        )

      expect(result.first).to eq({ id: "engagement", visible: true })
    end
  end
end
