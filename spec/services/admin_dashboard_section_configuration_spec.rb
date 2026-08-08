# frozen_string_literal: true

describe AdminDashboardSectionConfiguration do
  fab!(:admin)
  fab!(:category)
  fab!(:category_2, :category)

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

  describe ".settings_for" do
    it "returns an empty hash when nothing is persisted" do
      expect(described_class.settings_for("engagement")).to eq({})
    end

    it "returns the persisted settings for the section" do
      described_class.update_setting(
        section_id: "engagement",
        key: "activity_by_category",
        attrs: {
          category_ids: [category.id, category_2.id],
        },
      )

      expect(described_class.settings_for("engagement")).to eq(
        { "activity_by_category" => { "category_ids" => [category.id, category_2.id] } },
      )
    end

    it "returns the persisted settings for whos_posting independently of activity_by_category" do
      described_class.update_setting(
        section_id: "engagement",
        key: "activity_by_category",
        attrs: {
          category_ids: [category.id],
        },
      )
      described_class.update_setting(
        section_id: "engagement",
        key: "whos_posting",
        attrs: {
          category_ids: [category_2.id],
        },
      )

      expect(described_class.settings_for("engagement")).to eq(
        {
          "activity_by_category" => {
            "category_ids" => [category.id],
          },
          "whos_posting" => {
            "category_ids" => [category_2.id],
          },
        },
      )
    end
  end

  describe ".setting_definition" do
    let(:plugin) { Plugin::Instance.new }

    let(:fake_setting) do
      Class.new do
        def self.permit
          [:category_id]
        end

        def self.validate(attrs)
          id = attrs[:category_id]
          raise Discourse::InvalidParameters.new(:category_id) if id.blank?
          { "category_id" => id.to_i }
        end
      end
    end

    def register_support_section(enabled: true)
      plugin.register_admin_dashboard_section(
        id: "support",
        enabled: -> { enabled },
        settings: {
          "category_id" => fake_setting,
        },
      ) { {} }
    end

    after do
      DiscoursePluginRegistry._raw_admin_dashboard_sections.reject! do |entry|
        entry[:value][:id] == "support"
      end
    end

    it "resolves a setting definition registered on an enabled plugin section" do
      register_support_section

      definition = described_class.setting_definition("support", "category_id")

      expect(definition[:permit]).to eq([:category_id])
      expect(definition[:validate].call(category_id: category.id)).to eq(
        { "category_id" => category.id },
      )
    end

    it "returns nil for an unregistered setting key on a plugin section" do
      register_support_section

      expect(described_class.setting_definition("support", "not_a_real_setting")).to be_nil
    end

    it "returns nil when the section's enabled proc is false" do
      register_support_section(enabled: false)

      expect(described_class.setting_definition("support", "category_id")).to be_nil
    end
  end

  describe ".update_setting" do
    it "persists a valid selection under its key" do
      described_class.update_setting(
        section_id: "engagement",
        key: "activity_by_category",
        attrs: {
          category_ids: [category.id, category_2.id],
        },
      )

      expect(described_class.settings_for("engagement")).to eq(
        { "activity_by_category" => { "category_ids" => [category.id, category_2.id] } },
      )
    end

    it "persists a valid selection for whos_posting under its key" do
      described_class.update_setting(
        section_id: "engagement",
        key: "whos_posting",
        attrs: {
          category_ids: [category.id, category_2.id],
        },
      )

      expect(described_class.settings_for("engagement")).to eq(
        { "whos_posting" => { "category_ids" => [category.id, category_2.id] } },
      )
    end

    it "raises when more than the allowed number of categories are given for whos_posting" do
      expect {
        described_class.update_setting(
          section_id: "engagement",
          key: "whos_posting",
          attrs: {
            category_ids: (1..11).to_a,
          },
        )
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises when a category with the given id does not exist" do
      expect {
        described_class.update_setting(
          section_id: "engagement",
          key: "activity_by_category",
          attrs: {
            category_ids: [category.id, Category.maximum(:id) + 1],
          },
        )
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises when more than the allowed number of categories are given" do
      expect {
        described_class.update_setting(
          section_id: "engagement",
          key: "activity_by_category",
          attrs: {
            category_ids: (1..11).to_a,
          },
        )
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises when category ids are duplicated" do
      expect {
        described_class.update_setting(
          section_id: "engagement",
          key: "activity_by_category",
          attrs: {
            category_ids: [1, 1, 2],
          },
        )
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "deep-merges so pre-existing settings keys are preserved" do
      AdminDashboardSection.find_by(section_id: "engagement").update!(
        settings: {
          "legacy" => {
            "kept" => true,
          },
        },
      )

      described_class.update_setting(
        section_id: "engagement",
        key: "activity_by_category",
        attrs: {
          category_ids: [category.id],
        },
      )

      expect(described_class.settings_for("engagement")).to eq(
        {
          "legacy" => {
            "kept" => true,
          },
          "activity_by_category" => {
            "category_ids" => [category.id],
          },
        },
      )
    end

    it "raises for an unknown section id" do
      expect {
        described_class.update_setting(
          section_id: "frobnitz",
          key: "activity_by_category",
          attrs: {
            category_ids: [1],
          },
        )
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises for a known section that supports no settings" do
      expect {
        described_class.update_setting(
          section_id: "traffic",
          key: "activity_by_category",
          attrs: {
            category_ids: [1],
          },
        )
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises for a setting key not supported by the section" do
      expect {
        described_class.update_setting(
          section_id: "engagement",
          key: "not_a_real_setting",
          attrs: {
          },
        )
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "leaves settings untouched when the section is reordered or hidden" do
      described_class.update_setting(
        section_id: "engagement",
        key: "activity_by_category",
        attrs: {
          category_ids: [category.id, category_2.id],
        },
      )

      described_class.update(
        [{ id: "engagement", visible: false }, { id: "reports", visible: true }],
        actor: admin,
      )

      expect(described_class.settings_for("engagement")).to eq(
        { "activity_by_category" => { "category_ids" => [category.id, category_2.id] } },
      )
    end

    let(:plugin) { Plugin::Instance.new }

    let(:fake_setting) do
      Class.new do
        def self.permit
          [:category_id]
        end

        def self.validate(attrs)
          id = attrs[:category_id]
          raise Discourse::InvalidParameters.new(:category_id) if id.blank?
          { "category_id" => id.to_i }
        end
      end
    end

    def register_support_section(enabled: true)
      plugin.register_admin_dashboard_section(
        id: "support",
        enabled: -> { enabled },
        settings: {
          "category_id" => fake_setting,
        },
      ) { {} }
    end

    after do
      DiscoursePluginRegistry._raw_admin_dashboard_sections.reject! do |entry|
        entry[:value][:id] == "support"
      end
    end

    it "creates a section row on the fly when persisting a plugin section's setting for the first time" do
      register_support_section
      expect(AdminDashboardSection.find_by(section_id: "support")).to be_nil

      described_class.update_setting(
        section_id: "support",
        key: "category_id",
        attrs: {
          category_id: category.id,
        },
      )

      record = AdminDashboardSection.find_by(section_id: "support")
      expect(record.settings).to eq({ "category_id" => { "category_id" => category.id } })
    end

    it "still raises for an unregistered setting key on a plugin section" do
      register_support_section

      expect {
        described_class.update_setting(section_id: "support", key: "not_a_real_setting", attrs: {})
      }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe "plugin sections" do
    let(:plugin) { Plugin::Instance.new }

    def register_support_section(enabled:)
      plugin.register_admin_dashboard_section(id: "support", enabled: enabled) { {} }
    end

    after do
      DiscoursePluginRegistry._raw_admin_dashboard_sections.reject! do |entry|
        entry[:value][:id] == "support"
      end
    end

    it "includes an enabled plugin section, visible by default" do
      register_support_section(enabled: -> { true })

      expect(described_class.all_known_section_ids).to include("support")
      expect(described_class.sections).to include({ id: "support", visible: true })
      expect(described_class.visible_section_ids).to include("support")
    end

    it "hides a plugin section whose enabled proc returns false" do
      register_support_section(enabled: -> { false })

      expect(described_class.all_known_section_ids).not_to include("support")
      expect(described_class.sections.map { |s| s[:id] }).not_to include("support")
      expect(described_class.visible_section_ids).not_to include("support")
    end

    it "includes a plugin section that has no enabled proc" do
      register_support_section(enabled: nil)

      expect(described_class.all_known_section_ids).to include("support")
    end

    it "drops a disabled plugin section id passed to update" do
      register_support_section(enabled: -> { false })

      described_class.update([{ id: "support", visible: true }], actor: admin)

      expect(described_class.sections.map { |s| s[:id] }).not_to include("support")
    end
  end
end
