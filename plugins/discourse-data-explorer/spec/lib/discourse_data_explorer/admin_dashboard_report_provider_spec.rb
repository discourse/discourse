# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::AdminDashboardReportProvider do
  fab!(:admin)
  fab!(:user)
  fab!(:group)

  fab!(:visible_query) do
    Fabricate(
      :query,
      name: "Visible query",
      description: "Anyone can see this one",
      sql: "SELECT 1 AS value",
      hidden: false,
      user: admin,
    )
  end

  fab!(:hidden_query) do
    Fabricate(
      :query,
      name: "Hidden query",
      description: "Tucked away",
      sql: "SELECT 1 AS value",
      hidden: true,
      user: admin,
    )
  end

  let(:admin_guardian) { admin.guardian }
  let(:user_guardian) { user.guardian }

  before { SiteSetting.data_explorer_enabled = true }
  after { DiscourseDataExplorer::QueryRunner.invalidate(visible_query.id) }

  describe ".source_name" do
    it "is 'data_explorer_query'" do
      expect(described_class.source_name).to eq("data_explorer_query")
    end
  end

  describe ".label" do
    it "returns the localized 'Data Explorer' label" do
      expect(described_class.label).to eq(I18n.t("data_explorer.admin_dashboard_label"))
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
      expect(resolved.label).to eq(described_class.label)
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

  describe ".list_all" do
    it "lists visible queries" do
      reports = described_class.list_all
      expect(reports.map(&:identifier)).to include(visible_query.id.to_s)
    end

    it "omits hidden queries" do
      reports = described_class.list_all
      expect(reports.map(&:identifier)).not_to include(hidden_query.id.to_s)
    end

    it "filters by name/description when search is given" do
      reports = described_class.list_all(search: "Visible")
      expect(reports.map(&:identifier)).to eq([visible_query.id.to_s])
    end

    it "returns nothing when search matches no query" do
      expect(described_class.list_all(search: "zz_no_match_zz")).to be_empty
    end

    it "returns a title-sorted page and resumes after the cursor across persisted + defaults" do
      all = described_class.list_all
      titles = all.map { |report| report.title.to_s.downcase }
      expect(titles).to eq(titles.sort)

      first = described_class.list_all(limit: 1)
      expect(first.size).to eq(1)

      after = { title: first.first.title, key: first.first.key }
      second = described_class.list_all(after: after, limit: 1)

      expect(second.size).to eq(1)
      expect(second.first.identifier).not_to eq(first.first.identifier)
      expect(
        described_class.sort_key(second.first) <=> described_class.sort_key(first.first),
      ).to eq(1)
    end

    it "orders by byte value so an emoji-titled query never re-appears after its own cursor" do
      lettered =
        Fabricate(:query, name: "alpha query", sql: "SELECT 1 AS value", hidden: false, user: admin)
      emoji =
        Fabricate(
          :query,
          name: "🦁 lion query",
          sql: "SELECT 1 AS value",
          hidden: false,
          user: admin,
        )

      identifiers = described_class.list_all.map(&:identifier)
      expect(identifiers.index(lettered.id.to_s)).to be < identifiers.index(emoji.id.to_s)

      after = { title: emoji.name, key: "data_explorer_query:#{emoji.id}" }
      expect(described_class.list_all(after: after).map(&:identifier)).not_to include(
        lettered.id.to_s,
      )
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

    it "skips zero and non-numeric identifiers" do
      result = described_class.fetch_many(%w[0 abc], guardian: admin_guardian)
      expect(result).to be_empty
    end

    it "runs unpersisted default queries by negative id" do
      result = described_class.fetch_many(%w[-1], guardian: admin_guardian)
      expect(result["-1"]).to be_present
      expect(result["-1"][:success]).to eq(true)
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
