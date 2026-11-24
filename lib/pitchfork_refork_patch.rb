# frozen_string_literal: true

module PitchforkReforkPatch
  module Configurator
    def around_refork(*args, &block)
      set_hook(:around_refork, block_given? ? block : args[0], 3)
    end
  end

  attr_writer :around_refork

  private

  def spawn_mold(worker)
    return false unless @promotion_lock.try_lock

    begin
      worker.update_deadline(@timeout)
      mold_pid = nil
      proceed =
        lambda do
          raise "Refork continuation already called" if mold_pid
          mold_pid = spawn_mold_child(worker)
        end
      @around_refork ? @around_refork.call(self, worker, proceed) : proceed.call
    rescue StandardError
      @promotion_lock.at_fork
      raise
    else
      if mold_pid
        @promotion_lock.at_fork
      else
        @promotion_lock.unlock
      end
      !!mold_pid
    end
  end

  def spawn_mold_child(worker)
    worker.update_deadline(@spawn_timeout)
    @before_fork&.call(self)

    fork_sibling("spawn_mold") do
      mold = Pitchfork::Worker.new(nil, pid: Process.pid, generation: worker.generation)
      mold.promote!(@spawn_timeout)
      mold.start_promotion(@control_socket[1])
      mold_loop(mold)
    end
  end
end

if Pitchfork::VERSION != "0.18.2"
  raise "Review PitchforkReforkPatch for Pitchfork #{Pitchfork::VERSION}"
end

Pitchfork::Configurator.prepend(PitchforkReforkPatch::Configurator)
Pitchfork::HttpServer.prepend(PitchforkReforkPatch)
