# frozen_string_literal: true

RSpec.describe Admin::Search::List do
  describe Admin::Search::List::Contract, type: :model do
    it "accepts the supported search filters" do
      contract =
        described_class.new(
          filter_names: %w[min_topic_title_length default_locale],
          filter_area: "localization",
          plugin: "discourse-sample-plugin",
          categories: %w[reports localization],
        )

      expect(contract.filter_names).to eq(%w[min_topic_title_length default_locale])
      expect(contract.filter_area).to eq("localization")
      expect(contract.plugin).to eq("discourse-sample-plugin")
      expect(contract.categories).to eq(%w[reports localization])
    end

    describe "#include_locale_setting?" do
      it "returns true when filter_area is blank" do
        contract = described_class.new(filter_area: nil)
        expect(contract.include_locale_setting?).to eq(true)
      end

      it "returns true when filter_area is empty string" do
        contract = described_class.new(filter_area: "")
        expect(contract.include_locale_setting?).to eq(true)
      end

      it "returns true when filter_area is localization" do
        contract = described_class.new(filter_area: "localization")
        expect(contract.include_locale_setting?).to eq(true)
      end

      it "returns false when filter_area is something else" do
        contract = described_class.new(filter_area: "reports")
        expect(contract.include_locale_setting?).to eq(false)
      end
    end
  end

  describe ".call" do
    subject(:result) { Admin::Search::List.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:theme) { Fabricate(:theme, name: "Alpha Theme") }
    fab!(:component) { Fabricate(:theme, name: "Beta Component", component: true) }

    let(:guardian) { admin.guardian }
    let(:dependencies) { { guardian: } }
    let(:filter_names) { %w[min_topic_title_length default_locale] }
    let(:filter_area) { nil }
    let(:plugin) { nil }
    let(:categories) { [] }
    let(:params) { { filter_names:, filter_area:, plugin:, categories: } }

    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: :experimental,
            impact_type: "other",
            impact_role: "developers",
          },
        },
      )
    end

    context "when the current user is not an admin" do
      let(:guardian) { Fabricate(:user).guardian }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when the search area is blank" do
      it { is_expected.to run_successfully }

      it "returns the aggregated payload" do
        expect(result.settings.map { |setting| setting[:setting] }).to include(
          :default_locale,
          :min_topic_title_length,
        )
        expect(result.themes_and_components.map { |theme| theme[:name] }).to eq(
          ["Alpha Theme", "Beta Component", "Foundation", "Horizon"],
        )
        expect(result.reports.length).to eq(Reports::ListQuery.call(admin: true).length)
        expect(result.upcoming_changes.length).to be > 0
        expect(
          result.upcoming_changes.find { |change| change[:setting] == :enable_upload_debug_mode },
        ).to be_present
      end
    end

    context "when the search area is not localization" do
      let(:filter_area) { "reports" }

      it "excludes the default locale setting" do
        expect(result.settings.map { |setting| setting[:setting] }).not_to include(:default_locale)
      end
    end

    context "with a single category value" do
      let(:categories) { ["dashboard"] }
      let(:filter_names) { nil }

      it "only includes settings of that category" do
        expect(
          result.settings.map { |setting| SiteSetting.categories[setting[:setting]] }.uniq,
        ).to eq(["dashboard"])
      end
    end
  end
end
