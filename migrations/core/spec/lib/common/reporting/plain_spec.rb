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

  it "prints notices indented and attributed to their step" do
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

  it "silently ignores reports for an unknown step id" do
    expect {
      reporter.report_notice(999, "hi")
      reporter.report_progress_begin(999, 10)
      reporter.report_progress(999, 5, 0, 0, 0)
      reporter.report_finish(999, :done)
    }.not_to raise_error
    expect(io.string).to eq("")
  end

  it "treats a zero total as unknown and never divides by zero" do
    reporter.report_start(1, "Zero")
    reporter.report_progress_begin(1, 0)
    time[0] = 6.0
    reporter.report_progress(1, 3, 0, 0, 0)

    expect(lines).to include("    Zero 3 processed")
  end

  it "reports the full total and elapsed time on a done step even if progress lagged" do
    time[0] = 10.0
    reporter.report_start(1, "Lag")
    reporter.report_progress_begin(1, 100)
    reporter.report_progress(1, 40, 0, 0, 0)
    time[0] = 22.0
    reporter.report_finish(1, :done)

    expect(lines.last).to eq("✓ Lag 100 (0:12)")
  end

  it "keeps a count of one on the finish line" do
    reporter.report_start(1, "One")
    reporter.report_progress_begin(1, 1)
    reporter.report_progress(1, 1, 0, 0, 0)
    reporter.report_finish(1, :done)

    expect(lines.last).to eq("✓ One 1 (0:00)")
  end

  it "joins skip, warning, and error annotations with commas on the finish line" do
    reporter.report_start(1, "Counts")
    reporter.report_progress_begin(1, 10)
    reporter.report_progress(1, 10, 1, 1, 1)
    reporter.report_finish(1, :done)

    expect(lines.last).to eq("✓ Counts 10 (0:00) — 1 skip, 1 warning, 1 error")
  end

  it "reports the running count on a done step whose total was never known" do
    reporter.report_start(1, "NoTotal")
    reporter.report_progress_begin(1, nil)
    reporter.report_progress(1, 250, 0, 0, 0)
    reporter.report_finish(1, :done)

    expect(lines.last).to eq("✓ NoTotal 250 (0:00)")
  end

  it "marks an interrupted step and omits the count when nothing was processed" do
    reporter.report_start(1, "Empty")
    reporter.report_finish(1, :interrupted)

    expect(lines.last).to eq("⚠ Empty (0:00) — interrupted")
  end

  it "throttles heartbeats to one per interval, grouping the count and appending totals" do
    reporter.report_start(1, "Uploads")
    reporter.report_progress_begin(1, nil)
    reporter.report_progress(1, 100_000, 0, 1, 0) # t=0, too soon
    time[0] = 6.0
    reporter.report_progress(1, 200_000, 0, 1, 0) # >5s later, heartbeat
    time[0] = 8.0
    reporter.report_progress(1, 300_000, 0, 1, 0) # <5s later, no heartbeat

    expect(lines.grep(/processed/)).to contain_exactly("    Uploads 200,000 processed — 1 warning")
  end

  it "clamps the logged percent at 100 when progress overshoots the total" do
    reporter.report_start(1, "Over")
    reporter.report_progress_begin(1, 10)
    reporter.report_progress(1, 25, 0, 0, 0) # 250% overshoot

    expect(lines).to include("    Over 100% (25/10)")
  end

  it "ignores concurrency updates without printing or raising" do
    reporter.report_start(1, "X")

    expect { reporter.report_concurrency(1, 4) }.not_to raise_error
    expect(io.string).to eq("X\n")
  end

  it "leaves failed and skipped out of the summary when both are zero" do
    reporter.report_summary(runtime: 5.0, total: 3, failed: 0, skipped: 0)

    expect(lines.last).to eq("Total: 3 steps (0:05)")
  end

  it "lists a single failed and skipped step in the summary" do
    reporter.report_summary(runtime: 60.0, total: 4, failed: 1, skipped: 1)

    expect(lines.last).to eq("Total: 4 steps, 1 failed, 1 skipped (1:00)")
  end

  it "falls back to the monotonic clock when none is injected" do
    plain = described_class.new(output: io)
    plain.report_start(1, "Clocked")
    plain.report_finish(1, :done)

    expect(lines.last).to match(/\A✓ Clocked \(\d:\d\d\)\z/)
  end

  it "defaults its output to $stdout" do
    allow($stdout).to receive(:puts)
    plain = described_class.new(clock: -> { 0.0 })
    plain.report_start(1, "Default")

    expect($stdout).to have_received(:puts).with("Default")
  end

  it "enables sync on an output that supports it" do
    recorder =
      Class
        .new do
          attr_accessor :sync

          def initialize
            @sync = false
          end

          def puts(_line)
          end
        end
        .new
    described_class.new(output: recorder, clock: -> { 0.0 })

    expect(recorder.sync).to be(true)
  end

  it "tolerates an output that has no sync= setter" do
    sink = []
    out = Object.new
    out.define_singleton_method(:puts) { |line| sink << line }
    plain = described_class.new(output: out, clock: -> { 0.0 })
    plain.report_start(1, "Plain")

    expect(sink).to eq(["Plain"])
  end
end
