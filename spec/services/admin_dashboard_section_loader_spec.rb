# frozen_string_literal: true

describe AdminDashboardSectionLoader do
  fab!(:admin)

  after do
    if thread_pool = described_class.instance_variable_get(:@thread_pool)
      thread_pool.shutdown
      thread_pool.wait_for_termination(timeout: 1)
      described_class.remove_instance_variable(:@thread_pool)
    end
  end

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
  end
end
