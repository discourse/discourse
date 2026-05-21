# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::AdminDashboardReportProvider do
  fab!(:admin)
  fab!(:user)
  fab!(:group)

  let(:admin_guardian) { Guardian.new(admin) }
  let(:user_guardian) { Guardian.new(user) }

  let!(:visible_query) do
    Fabricate(
      :query,
      name: "Visible query",
      description: "Anyone can see this one",
      sql: "SELECT 1 AS value",
      hidden: false,
      user: admin,
    )
  end

  let!(:hidden_query) do
    Fabricate(
      :query,
      name: "Hidden query",
      description: "Tucked away",
      sql: "SELECT 1 AS value",
      hidden: true,
      user: admin,
    )
  end

  before { SiteSetting.data_explorer_enabled = true }
  after { DiscourseDataExplorer::QueryRunner.invalidate(visible_query.id) }

  describe ".source_name" do
    it "is 'data_explorer_query'" do
      expect(described_class.source_name).to eq("data_explorer_query")
    end
  end

  describe ".resolve_many" do
    it "resolves visible queries by id" do
      result = described_class.resolve_many([visible_query.id.to_s], guardian: admin_guardian)

      expect(result.keys).to eq([visible_query.id.to_s])
      resolved = result[visible_query.id.to_s]
      expect(resolved).to be_a(AdminDashboard::Reports::ResolvedReport)
      expect(resolved.title).to eq("Visible query")
      expect(resolved.description).to eq("Anyone can see this one")
      expect(resolved.source).to eq("data_explorer_query")
    end

    it "omits hidden queries" do
      result = described_class.resolve_many([hidden_query.id.to_s], guardian: admin_guardian)
      expect(result).to be_empty
    end

    it "omits unknown ids" do
      result = described_class.resolve_many(["999999"], guardian: admin_guardian)
      expect(result).to be_empty
    end

    it "returns an empty hash when guardian is nil" do
      expect(described_class.resolve_many([visible_query.id.to_s], guardian: nil)).to be_empty
    end

    context "for a non-admin user" do
      it "omits queries the user has no access to" do
        result = described_class.resolve_many([visible_query.id.to_s], guardian: user_guardian)
        expect(result).to be_empty
      end

      it "resolves queries the user can access via group membership" do
        DiscourseDataExplorer::QueryGroup.create!(query: visible_query, group: group)
        group.add(user)

        result = described_class.resolve_many([visible_query.id.to_s], guardian: user_guardian)
        expect(result.keys).to eq([visible_query.id.to_s])
      end
    end
  end

  describe ".available_for" do
    it "lists visible queries" do
      reports = described_class.available_for(admin_guardian)
      expect(reports.map(&:identifier)).to include(visible_query.id.to_s)
    end

    it "omits hidden queries" do
      reports = described_class.available_for(admin_guardian)
      expect(reports.map(&:identifier)).not_to include(hidden_query.id.to_s)
    end

    it "filters by name/description when search is given" do
      reports = described_class.available_for(admin_guardian, search: "Visible")
      expect(reports.map(&:identifier)).to eq([visible_query.id.to_s])
    end

    it "returns nothing when search matches no query" do
      expect(described_class.available_for(admin_guardian, search: "zz_no_match_zz")).to be_empty
    end
  end

  describe ".fetch_many" do
    it "returns nothing for queries the user can't access" do
      result = described_class.fetch_many([visible_query.id.to_s], guardian: user_guardian)
      expect(result).to be_empty
    end

    it "runs the query and returns the result for an admin" do
      result = described_class.fetch_many([visible_query.id.to_s], guardian: admin_guardian)

      payload = result[visible_query.id.to_s]
      expect(payload).to be_present
      expect(payload[:success]).to eq(true)
      expect(payload[:columns]).to include("value")
    end

    it "returns nothing for non-positive identifiers" do
      result = described_class.fetch_many(%w[0 -1 abc], guardian: admin_guardian)
      expect(result).to be_empty
    end
  end

  describe "registration" do
    it "is registered as a provider on boot" do
      expect(AdminDashboard::Reports::Registry.provider_for("data_explorer_query")).to eq(
        described_class,
      )
    end
  end
end
