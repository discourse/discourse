# frozen_string_literal: true

describe AdminDashboardSectionConfiguration do
  fab!(:admin)

  describe ".sections" do
    it "returns every seeded section, all visible, in canonical order by default" do
      expect(described_class.sections).to eq(
        [
          { id: "highlights", visible: true },
          { id: "reports", visible: true },
          { id: "traffic", visible: true },
          { id: "engagement", visible: true },
          { id: "search", visible: true },
        ],
      )
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

      expect(described_class.sections).to eq(
        [
          { id: "highlights", visible: false },
          { id: "reports", visible: true },
          { id: "traffic", visible: true },
          { id: "engagement", visible: true },
          { id: "search", visible: true },
        ],
      )
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
          { id: "search", visible: false },
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
          { id: "search", visible: true },
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
          { id: "search", visible: true },
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
          { id: "search", visible: "f" },
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

  describe "plugin sections" do
    def stub_plugin_sections(sections)
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(sections)
    end

    it "includes an enabled plugin section, visible by default" do
      stub_plugin_sections([{ id: "support", enabled: -> { true }, loader: -> {} }])

      expect(described_class.all_known_section_ids).to include("support")
      expect(described_class.sections).to include({ id: "support", visible: true })
      expect(described_class.visible_section_ids).to include("support")
    end

    it "hides a plugin section whose enabled proc returns false" do
      stub_plugin_sections([{ id: "support", enabled: -> { false }, loader: -> {} }])

      expect(described_class.all_known_section_ids).not_to include("support")
      expect(described_class.sections.map { |s| s[:id] }).not_to include("support")
      expect(described_class.visible_section_ids).not_to include("support")
    end

    it "includes a plugin section that has no enabled proc" do
      stub_plugin_sections([{ id: "support", enabled: nil, loader: -> {} }])

      expect(described_class.all_known_section_ids).to include("support")
    end

    it "drops a disabled plugin section id passed to update" do
      stub_plugin_sections([{ id: "support", enabled: -> { false }, loader: -> {} }])

      described_class.update([{ id: "support", visible: true }], actor: admin)

      expect(described_class.sections.map { |s| s[:id] }).not_to include("support")
    end
  end
end
