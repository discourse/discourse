# frozen_string_literal: true

describe AdminDashboardSectionConfiguration do
  fab!(:admin)

  before { SiteSetting.admin_dashboard_sections = "highlights|reports|traffic|engagement" }

  describe "the site setting" do
    it "rejects unknown ids at the validator level" do
      expect { SiteSetting.admin_dashboard_sections = "frobnitz|highlights" }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end

  describe ".visible_section_ids" do
    it "returns ids in stored order" do
      SiteSetting.admin_dashboard_sections = "reports|highlights|engagement"
      expect(described_class.visible_section_ids).to eq(%w[reports highlights engagement])
    end

    it "dedupes repeated ids, keeping the first occurrence" do
      SiteSetting.admin_dashboard_sections = "highlights|highlights|reports"
      expect(described_class.visible_section_ids).to eq(%w[highlights reports])
    end

    it "returns an empty array when the setting is empty" do
      SiteSetting.admin_dashboard_sections = ""
      expect(described_class.visible_section_ids).to eq([])
    end

    it "falls back to canonical defaults when the raw value is non-empty but unusable" do
      SiteSetting.stubs(:admin_dashboard_sections).returns("|||")
      expect(described_class.visible_section_ids).to eq(described_class::KNOWN_SECTIONS)
    end

    it "falls back to canonical defaults when every id is unknown" do
      SiteSetting.stubs(:admin_dashboard_sections).returns("frobnitz|wibble")
      expect(described_class.visible_section_ids).to eq(described_class::KNOWN_SECTIONS)
    end
  end

  describe ".sections" do
    it "returns visible sections first, then hidden in canonical order" do
      SiteSetting.admin_dashboard_sections = "reports|engagement"

      expect(described_class.sections).to eq(
        [
          { id: "reports", visible: true },
          { id: "engagement", visible: true },
          { id: "highlights", visible: false },
          { id: "traffic", visible: false },
        ],
      )
    end

    it "marks every known section visible: false when the setting is empty" do
      SiteSetting.admin_dashboard_sections = ""

      expect(described_class.sections.map { |s| s[:visible] }.uniq).to eq([false])
      expect(described_class.sections.map { |s| s[:id] }).to match_array(
        described_class::KNOWN_SECTIONS,
      )
    end
  end

  describe ".update" do
    it "persists the visible ids as a pipe-delimited string" do
      described_class.update(
        [{ id: "reports", visible: true }, { id: "highlights", visible: true }],
        actor: admin,
      )

      expect(SiteSetting.admin_dashboard_sections).to eq("reports|highlights")
    end

    it "drops sections with visible: false" do
      described_class.update(
        [
          { id: "highlights", visible: true },
          { id: "traffic", visible: false },
          { id: "reports", visible: true },
        ],
        actor: admin,
      )

      expect(SiteSetting.admin_dashboard_sections).to eq("highlights|reports")
    end

    it "coerces non-boolean visible values" do
      described_class.update(
        [
          { id: "highlights", visible: "true" },
          { id: "reports", visible: "false" },
          { id: "engagement", visible: 1 },
        ],
        actor: admin,
      )

      expect(SiteSetting.admin_dashboard_sections).to eq("highlights|engagement")
    end

    it "drops unknown section ids" do
      described_class.update(
        [{ id: "frobnitz", visible: true }, { id: "highlights", visible: true }],
        actor: admin,
      )

      expect(SiteSetting.admin_dashboard_sections).to eq("highlights")
    end

    it "accepts string keys as well as symbols" do
      described_class.update(
        [{ "id" => "highlights", "visible" => true }, { "id" => "reports", "visible" => true }],
        actor: admin,
      )

      expect(SiteSetting.admin_dashboard_sections).to eq("highlights|reports")
    end

    it "writes empty string when all sections are hidden" do
      described_class.update(
        [{ id: "highlights", visible: false }, { id: "reports", visible: false }],
        actor: admin,
      )

      expect(SiteSetting.admin_dashboard_sections).to eq("")
    end

    it "returns the new sections snapshot" do
      result =
        described_class.update(
          [{ id: "engagement", visible: true }, { id: "highlights", visible: true }],
          actor: admin,
        )

      expect(result.first(2)).to eq(
        [{ id: "engagement", visible: true }, { id: "highlights", visible: true }],
      )
    end
  end
end
