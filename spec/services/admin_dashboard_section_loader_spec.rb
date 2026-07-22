# frozen_string_literal: true

describe AdminDashboardSectionLoader do
  fab!(:admin)

  describe ".build" do
    it "ensures the sections are built in order with current user and dates" do
      AdminDashboardSiteTraffic
        .expects(:build)
        .with do |kwargs|
          kwargs[:start_date] == "2026-05-01" && kwargs[:end_date] == "2026-05-07" &&
            kwargs[:guardian].is_a?(Guardian) && kwargs[:guardian].user.id == admin.id
        end
        .returns({ value: "traffic" })
      AdminDashboardEngagement
        .expects(:build)
        .with(start_date: "2026-05-01", end_date: "2026-05-07", current_user: admin)
        .returns({ value: "engagement" })
      AdminDashboardSearch
        .expects(:build)
        .with(start_date: "2026-05-01", end_date: "2026-05-07")
        .returns({ value: "search" })

      expect(
        described_class.build(
          section_ids: %w[traffic engagement search],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq(
        [
          { id: "traffic", data: { value: "traffic" } },
          { id: "engagement", data: { value: "engagement" } },
          { id: "search", data: { value: "search" } },
        ],
      )
    end

    it "returns partial section data when a section fails to build" do
      error = StandardError.new("boom")
      AdminDashboardSiteTraffic.stubs(:build).returns({ value: "traffic" })
      AdminDashboardSearch.stubs(:build).raises(error)
      Discourse.expects(:warn_exception).with(
        error,
        message: "Failed to build admin dashboard section",
        env: {
          section_id: "search",
        },
      )

      expect(
        described_class.build(
          section_ids: %w[traffic search],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq(
        [{ id: "traffic", data: { value: "traffic" } }, { id: "search", data: nil, error: true }],
      )
    end
  end

  describe "plugin sections" do
    it "routes a registered plugin section id to its loader block" do
      loader = ->(start_date:, end_date:, current_user:) do
        { value: "support", user: current_user.id }
      end
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(
        [{ id: "support", enabled: -> { true }, loader: loader }],
      )

      expect(
        described_class.build(
          section_ids: ["support"],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq([{ id: "support", data: { value: "support", user: admin.id } }])
    end

    it "returns nil data for an unknown section id" do
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns([])

      expect(
        described_class.build(
          section_ids: ["frobnitz"],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq([{ id: "frobnitz", data: nil }])
    end
  end

  it "runs plugin loaders in the request thread so their SQL remains request-attributed" do
    loader_thread = nil
    loader = ->(start_date:, end_date:, current_user:) do
      loader_thread = Thread.current
      ActiveRecord::Base.connection.execute("SELECT 1")
      { value: "visible" }
    end
    DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(
      [{ id: "visible", enabled: -> { true }, loader: loader }],
    )

    result =
      described_class.build(
        section_ids: ["visible"],
        current_user: Discourse.system_user,
        start_date: "2026-05-01",
        end_date: "2026-05-07",
      )

    expect(result).to eq([{ id: "visible", data: { value: "visible" } }])
    expect(loader_thread).to eq(Thread.current)
  end
end
