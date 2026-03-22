# frozen_string_literal: true

module MiniRacerForkSafety
  @@init_blocked = false

  def initialize(*args, **kwargs)
    if @@init_blocked
      raise "#{self.class.name} cannot be initialized in a mold process. This would cause catastrophic issues when forking."
    end
  end

  def self.block_initialization!
    @@init_blocked = true
  end

  def self.allow_initialization!
    @@init_blocked = false
  end
end

MiniRacer::Context.prepend(MiniRacerForkSafety)

MiniRacer::Snapshot.prepend(MiniRacerForkSafety)
