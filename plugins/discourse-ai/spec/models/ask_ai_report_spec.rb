# frozen_string_literal: true

describe AskAiReport do
  fab!(:admin)

  it "expires queued and running reports without changing fresh or completed reports" do
    freeze_time
    reports =
      %i[queued running completed failed].map do |status|
        described_class.create!(
          requested_by: admin,
          start_date: Date.current,
          end_date: Date.current,
          total_ask_count: 1,
          reported_ask_count: 1,
          report_status: status,
          updated_at: 31.minutes.ago,
        )
      end
    fresh =
      described_class.create!(
        requested_by: admin,
        start_date: Date.current,
        end_date: Date.current,
        total_ask_count: 1,
        reported_ask_count: 1,
        report_status: :running,
        updated_at: 29.minutes.ago,
      )

    described_class.expire_stale!

    expect(reports.map { |report| report.reload.report_status }).to eq(
      %w[failed failed completed failed],
    )
    expect(fresh.reload).to be_report_status_running
  end
end
