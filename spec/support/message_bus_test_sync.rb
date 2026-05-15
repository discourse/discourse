# frozen_string_literal: true

# Records MessageBus publishes in system tests and waits for the client
# to catch up, to prevent flakes in "publish then assert" scenarios.
module MessageBusTestSync
  MUTEX = Mutex.new
  LAST_IDS_SCRIPT = <<~JS
    Object.fromEntries(
      arguments[0].map((ch) => {
        const cb = (window.MessageBus?.callbacks ?? []).find((c) => c.channel === ch);
        return [ch, cb?.last_id ?? null];
      })
    )
  JS

  @pending = nil

  def self.start
    MUTEX.synchronize { @pending = {} }
  end

  def self.stop
    MUTEX.synchronize { @pending = nil }
  end

  def self.pending?
    @pending&.any?
  end

  def self.record(channel, id)
    return if id.nil? || @pending.nil?
    MUTEX.synchronize do
      next if @pending.nil?
      current = @pending[channel]
      @pending[channel] = id if current.nil? || id > current
    end
  end

  # Polls the browser until each recorded id is observed on its callback,
  # or `timeout` elapses. Channels with no `last_id` are skipped.
  def self.flush!(session, timeout:)
    snapshot =
      MUTEX.synchronize do
        return if @pending.nil? || @pending.empty?
        taken = @pending
        @pending = {}
        taken
      end

    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    backoff = 0.01

    loop do
      client_ids = session.evaluate_script(LAST_IDS_SCRIPT, snapshot.keys)
      snapshot.select! { |ch, id| client_ids[ch].is_a?(Integer) && client_ids[ch] < id }

      return if snapshot.empty?
      return if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep backoff
      backoff = [backoff * 1.5, 0.1].min # grow per retry, cap at 100ms
    end
  end

  module PublishHook
    def publish(channel, data, opts = nil)
      id = super
      MessageBusTestSync.record(channel, id)
      id
    end
  end

  MessageBus::Implementation.prepend(PublishHook)
end
