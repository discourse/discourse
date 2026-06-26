# frozen_string_literal: true

# A standalone driver that exercises the *real* reporter (selected by
# Reporting::Factory, so the tty/TERM ladder runs for real) under whatever stdout
# it is given. The PTY spec spawns it; it is never run in-process, so the body
# is guarded and the `require` that `load_support` does is a harmless no-op.
#
# Scenarios (TUI_DRIVER_SCENARIO):
#   "full"      — several short steps + notices, enough output to exceed a small
#                 terminal, then a clean exit.
#   "interrupt" — one long-running step so the spec can deliver SIGINT mid-step.
module TuiReporterDriver
  PATH = __FILE__
end

if $PROGRAM_NAME == __FILE__
  require "migrations-core"
  Migrations.enable_i18n
  Migrations.apply_global_config

  scenario = ENV.fetch("TUI_DRIVER_SCENARIO", "full")

  # Record terminal settings before/after so the spec can prove the reporter
  # left the tty exactly as it found it (it runs in cooked mode and never pokes
  # termios, so this must hold even after a SIGINT).
  stty_file = ENV["TUI_DRIVER_STTY_FILE"]
  stty_before = (`stty -g 2>/dev/null`.strip if stty_file)

  reporter = Migrations::Reporting::Factory.build

  interrupted = false

  run_step =
    lambda do |title, total, ticks, tick_seconds, warn: 0, notice: nil|
      step = reporter.start_step(title)
      step.notice(notice) if notice
      begin
        step.with_progress(max_progress: total) do |progress|
          increment = total ? (total / ticks.to_f).ceil : 1000
          ticks.times do |i|
            sleep tick_seconds
            progress.update(increment_by: increment, warning_count: (i.zero? ? warn : 0))
          end
        end
      ensure
        step.finish
      end
    end

  begin
    case scenario
    when "interrupt"
      run_step.call("Posts", 1_000_000, 500, 0.02) # ~10s; the spec interrupts mid-step
    else
      run_step.call("Categories", 4_281, 5, 0.02)
      run_step.call("Users", 312_440, 5, 0.02, warn: 17)
      run_step.call("Posts", 1_248_776, 6, 0.02, notice: "Re-checking orphaned uploads")
      run_step.call("Tags", 10_944, 4, 0.02)
      run_step.call("Uploads", nil, 4, 0.02) # indeterminate
    end
  rescue Interrupt
    interrupted = true
  ensure
    reporter.close
  end

  File.write(stty_file, "#{stty_before}\n#{`stty -g 2>/dev/null`.strip}\n") if stty_file

  exit(interrupted ? 130 : 0)
end
