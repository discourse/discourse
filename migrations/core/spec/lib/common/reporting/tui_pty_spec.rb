# frozen_string_literal: true

require "pty"
require "io/console"
require "tempfile"

# End-to-end: the real reporter, selected by Reporting::Factory, driven under a
# real PTY (or a plain pipe). This is the regression net that mechanically
# catches rendering artifacts a unit test can't — the reconstructed screen comes
# from AnsiScreen.
RSpec.describe Migrations::Reporting::Tui do
  DRIVER = TuiReporterDriver::PATH

  # Runs the driver to completion, returns [raw_output, status]. `actions` is a
  # list of [delay_seconds, :signal|:resize, arg] performed against the PTY.
  def run_under_pty(scenario:, rows:, cols:, term: "xterm-256color", actions: [], stty_file: nil)
    env = { "TUI_DRIVER_SCENARIO" => scenario, "TERM" => term }
    env["TUI_DRIVER_STTY_FILE"] = stty_file if stty_file

    reader, _writer, pid = PTY.spawn(env, "bundle", "exec", "ruby", DRIVER)
    reader.winsize = [rows, cols]

    out = +"".b
    out_mutex = Mutex.new
    pump =
      Thread.new do
        loop { out_mutex.synchronize { out << reader.readpartial(65_536) } }
      rescue EOFError, Errno::EIO
        nil
      end

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    actions.each do |delay, kind, arg|
      sleep([start + delay - Process.clock_gettime(Process::CLOCK_MONOTONIC), 0].max)
      case kind
      when :signal
        Process.kill(arg, pid)
      when :resize
        reader.winsize = arg
      end
    end

    _, status = Process.wait2(pid)
    pump.join(2)
    begin
      reader.close
    rescue StandardError
      nil
    end
    [out_mutex.synchronize { out.dup.force_encoding("UTF-8") }, status]
  end

  def run_piped(scenario:, term: "xterm-256color")
    Tempfile.create("tui-pipe") do |file|
      env = { "TUI_DRIVER_SCENARIO" => scenario, "TERM" => term }
      pid = spawn(env, "bundle", "exec", "ruby", DRIVER, out: file.path, err: File::NULL)
      _, status = Process.wait2(pid)
      [File.read(file.path), status]
    end
  end

  it "keeps the full history in scrollback when output exceeds a short terminal" do
    out, status = run_under_pty(scenario: "full", rows: 10, cols: 100)

    expect(status.exitstatus).to eq(0)
    screen = AnsiScreen.new(width: 100).feed(out)
    history = screen.content_rows.join("\n")

    # Every finished step persists, even though the live region is only a few
    # rows and the run produced far more than 10 rows of output.
    %w[Categories Users Posts Tags Uploads].each { |title| expect(history).to match(/✓ #{title}/) }
    expect(history).to include("Re-checking orphaned uploads") # a notice, too
    expect(out).to end_with(Migrations::Reporting::Tui::Ansi::SHOW_CURSOR) # cursor restored
  end

  it "exits cleanly on SIGINT: code 130, cursor shown, tty untouched, interrupt persisted" do
    stty = Tempfile.new("tui-stty")
    stty.close
    out, status =
      run_under_pty(
        scenario: "interrupt",
        rows: 20,
        cols: 100,
        actions: [[1.5, :signal, "INT"]],
        stty_file: stty.path,
      )

    expect(status.exitstatus).to eq(130)
    expect(out).to include(Migrations::Reporting::Tui::Ansi::SHOW_CURSOR)
    expect(out).to end_with(Migrations::Reporting::Tui::Ansi::SHOW_CURSOR)

    screen = AnsiScreen.new(width: 100).feed(out)
    expect(screen.content_rows.join("\n")).to match(/Posts.*interrupted at \d+%/)

    before, after = File.read(stty.path).lines.map(&:chomp)
    expect(after).to eq(before) unless before.to_s.empty? # cooked mode left untouched
  ensure
    stty&.unlink
  end

  it "selects the Plain reporter for a pipe (no tty)" do
    out, status = run_piped(scenario: "full")

    expect(status.exitstatus).to eq(0)
    expect(out).not_to match(/\e\[/) # no cursor/color control sequences
    expect(out).to match(/^✓ Categories [\d,]+ \((<1s|\d+:\d{2})\)$/)
    expect(out).to match(/Users \d+%/) # 10% progress log
  end

  it "selects the Plain reporter for TERM=dumb even on a tty" do
    out, status = run_under_pty(scenario: "full", rows: 24, cols: 100, term: "dumb")

    expect(status.exitstatus).to eq(0)
    expect(out).not_to match(/\e\[/)
    expect(out).to match(/✓ Categories [\d,]+ \((<1s|\d+:\d{2})\)/)
  end
end
