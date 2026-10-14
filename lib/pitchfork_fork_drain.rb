# frozen_string_literal: true
require_relative "scheduler/fork_drain"

module PitchforkForkDrain
  DRAIN_TIMEOUT = 30
  private_constant :DRAIN_TIMEOUT

  def spawn_mold(worker)
    return false unless @promotion_lock.try_lock

    owner = Process.pid
    begin
      worker.update_deadline(DRAIN_TIMEOUT + @spawn_timeout)
      return false unless Scheduler::ForkDrain.drain(timeout: DRAIN_TIMEOUT)

      worker.update_deadline(@spawn_timeout)
      @before_fork&.call(self)
      fork_sibling("spawn_mold") do
        mold = Pitchfork::Worker.new(nil, pid: Process.pid, generation: worker.generation)
        mold.promote!(@spawn_timeout)
        mold.start_promotion(@control_socket[1])
        mold_loop(mold)
      end
      true
    ensure
      if owner == Process.pid
        Scheduler::ForkDrain.resume
        @promotion_lock.at_fork
        worker.update_deadline(@timeout)
      end
    end
  end
end

Pitchfork::HttpServer.prepend(PitchforkForkDrain)
