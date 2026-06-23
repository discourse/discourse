# frozen_string_literal: true

# TEMPORARY DEBUG INSTRUMENTATION (revert before merge).
#
# Diagnoses MiniRacer::ScriptTerminatedError seen after the mini_racer
# 0.21.0 -> 0.21.3 upgrade (e.g. spec/system/table_builder_spec.rb). The open
# question is whether the cook is genuinely hitting the 25s V8 watchdog (a real
# slowdown/hang) or being aborted instantly by a thread interrupt / cross-thread
# stop+dispose (0.21.3 wires an rb_nogvl unblock fn that calls
# v8_terminate_execution; 0.21.0 used a NULL ubf and deferred interrupts).
#
# It records, on every ScriptTerminatedError: the elapsed time of THAT eval/call
# (≈25000ms => watchdog; tiny => instant abort), plus a snapshot of every live
# thread's backtrace, and it logs stop/dispose/low_memory_notification so a
# concurrent terminator on the shared context is visible in the timeline.

if defined?(MiniRacer)
  module MiniRacerDebug
    WATCHDOG_MS = 25_000

    def self.stamp
      format("%.3f", Process.clock_gettime(Process::CLOCK_MONOTONIC))
    end

    def self.log(msg)
      warn("[MR-DEBUG t=#{stamp} pid=#{Process.pid} thr=#{Thread.current.object_id}] #{msg}")
    end

    def self.dump_termination(label, elapsed_ms, error)
      verdict =
        if elapsed_ms >= WATCHDOG_MS - 1_500
          "≈25s WATCHDOG TIMEOUT — genuine slowdown/hang"
        else
          "INSTANT ABORT (#{elapsed_ms}ms ≪ 25s) — interrupt/stop/dispose, NOT a slowdown"
        end

      out = +"\n#{"=" * 80}\n"
      out << "[MR-DEBUG] ScriptTerminatedError during #{label}\n"
      out << "  VERDICT: #{verdict}\n"
      out << "  eval_elapsed_ms=#{elapsed_ms}\n"
      out << "  mini_racer=#{MiniRacer::VERSION} " \
             "single_threaded=#{GlobalSetting.mini_racer_single_threaded rescue "?"}\n"
      out << "  pid=#{Process.pid} live_threads=#{Thread.list.size} " \
             "current_thread=#{Thread.current.object_id}\n"
      out << "  error=#{error.class}: #{error.message}\n"
      Thread.list.each_with_index do |t, i|
        marker = t == Thread.current ? " (CURRENT)" : ""
        out << "  --- thread[#{i}] id=#{t.object_id} status=#{t.status.inspect}#{marker}\n"
        Array(t.backtrace).first(15).each { |frame| out << "        #{frame}\n" }
      end
      out << "#{"=" * 80}\n"
      warn(out)
    end
  end

  module MiniRacerContextDebug
    def eval(...)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      super
    rescue MiniRacer::ScriptTerminatedError => e
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
      MiniRacerDebug.dump_termination("Context#eval", elapsed, e)
      raise
    end

    def call(...)
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      super
    rescue MiniRacer::ScriptTerminatedError => e
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0) * 1000).round(1)
      MiniRacerDebug.dump_termination("Context#call", elapsed, e)
      raise
    end

    def stop(...)
      MiniRacerDebug.log("Context#stop\n  #{caller.first(8).join("\n  ")}")
      super
    end

    def dispose(...)
      MiniRacerDebug.log("Context#dispose\n  #{caller.first(8).join("\n  ")}")
      super
    end
  end

  MiniRacer::Context.prepend(MiniRacerContextDebug)
  MiniRacerDebug.log("instrumentation loaded (mini_racer #{MiniRacer::VERSION})")
end
