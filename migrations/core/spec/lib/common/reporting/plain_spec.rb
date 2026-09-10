# frozen_string_literal: true

require "stringio"

RSpec.describe Migrations::Reporting::Plain do
  subject(:reporter) { described_class.new(output: io, clock: -> { time[0] }) }

  let(:io) { StringIO.new }
  let(:time) { [0.0] }

  def lines
    io.string.lines.map(&:chomp)
  end

  it "prints one line per step start and finish, with the total and duration" do
    step = reporter.start_step("Categories")
    step.with_progress(max_progress: 4281) { |p| p.update(increment_by: 4281) }
    time[0] = 12.0
    step.finish

    expect(lines.first).to eq("Categories")
    expect(lines.last).to match(/\A✓ Categories 4,281 \(0:12\)\z/)
  end

  it "prints notices indented under their step" do
    step = reporter.start_step("Posts")
    step.notice("Calculating items took 6 seconds")
    expect(lines).to include("    Posts Calculating items took 6 seconds")
  end

  it "keeps two steps with the same title independent (distinct ids, no clobber)" do
    a = reporter.start_step("Dupe")
    b = reporter.start_step("Dupe")
    a.with_progress(max_progress: 100) { |p| p.update(increment_by: 100) }
    b.with_progress(max_progress: 7) { |p| p.update(increment_by: 7) }
    a.finish
    b.finish

    expect(lines).to include(a_string_matching(/\A✓ Dupe 100 /), a_string_matching(/\A✓ Dupe 7 /))
  end

  it "logs progress once every 10%, with the count" do
    step = reporter.start_step("Users")
    step.with_progress(max_progress: 100) { |p| 100.times { p.update(increment_by: 1) } }

    progress_lines = lines.grep(/Users \d+%/)
    expect(progress_lines.size).to eq(10) # 10%..100%, once each
    expect(progress_lines.first).to eq("    Users 10% (10/100)")
    expect(progress_lines.last).to eq("    Users 100% (100/100)")
  end

  it "logs a periodic heartbeat for an unknown-total step" do
    step = reporter.start_step("Uploads")
    step.with_progress(max_progress: nil) do |progress|
      progress.update(increment_by: 100) # too soon, no heartbeat
      time[0] = 6.0
      progress.update(increment_by: 100) # >5s later, heartbeat
    end

    heartbeats = lines.grep(/Uploads .* processed/)
    expect(heartbeats).to contain_exactly("    Uploads 200 processed")
  end

  it "appends warning/error/skip totals to the finish line" do
    step = reporter.start_step("Users")
    step.with_progress(max_progress: 10) do |progress|
      progress.update(increment_by: 10, skip_count: 1, warning_count: 2, error_count: 3)
    end
    step.finish

    finish = lines.last
    expect(finish).to include("1 skip")
    expect(finish).to include("2 warnings")
    expect(finish).to include("3 errors")
  end

  it "marks failed and interrupted outcomes" do
    failed = described_class.new(output: io, clock: -> { time[0] })
    handle = failed.start_step("Boom")
    begin
      handle.with_progress(max_progress: 10) do |p|
        p.update(increment_by: 3)
        raise "boom"
      end
    rescue StandardError
      handle.finish
    end

    expect(lines.last).to match(/\A✗ Boom 3 \(.*\) — failed\z/)
  end

  it "writes no cursor-control sequences" do
    step = reporter.start_step("Users")
    step.with_progress(max_progress: 10) { |p| 10.times { p.update(increment_by: 1) } }
    step.finish
    reporter.close

    expect(io.string).not_to match(/\e\[/)
  end

  it "accumulates update deltas exactly under concurrent producers" do
    step = reporter.start_step("Users")
    step.with_progress(max_progress: 800) do |progress|
      8.times.map { Thread.new { 100.times { progress.update(increment_by: 1) } } }.each(&:join)
    end

    expect(lines).to include("    Users 100% (800/800)")
  end

  it "prints a finishing-up line and a run summary" do
    reporter.finalizing { nil }
    reporter.report_summary(runtime: 138.0, total: 24, failed: 2, skipped: 1)

    expect(lines).to include("Finishing up…")
    expect(lines.last).to eq("Total: 24 steps, 2 failed, 1 skipped (2:18)")
  end
end
