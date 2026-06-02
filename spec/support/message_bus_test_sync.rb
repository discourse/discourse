# frozen_string_literal: true

# Records MessageBus publishes in system tests and waits for the client
# to catch up, to prevent flakes in "publish then assert" scenarios.
module MessageBusTestSync
  MUTEX = Mutex.new
  CATCH_UP_SCRIPT = <<~JS
    const [pending, timeoutMs, done] = arguments;
    const deadline = Date.now() + timeoutMs;

    function poll() {
      const callbacks = window.MessageBus?.callbacks ?? [];
      const behind = [];

      for (const [channel, expectedId] of Object.entries(pending)) {
        const lastId = callbacks.find((c) => c.channel === channel)?.last_id;
        if (Number.isInteger(lastId) && lastId < expectedId) {
          behind.push({ channel, lastId, expectedId });
        }
      }

      if (behind.length === 0 || Date.now() >= deadline) {
        done(behind);
      } else {
        setTimeout(poll, 10);
      }
    }

    poll();
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
      @pending[channel] = id if id > (@pending[channel] || -1)
    end
  end

  # Waits until each recorded id is observed in the browser, or
  # `timeout` elapses. Channels with no `last_id` are skipped.
  def self.flush!(session, timeout:)
    snapshot =
      MUTEX.synchronize do
        return if @pending.nil? || @pending.empty?
        taken = @pending
        @pending = {}
        taken
      end

    session.evaluate_async_script(CATCH_UP_SCRIPT, snapshot, (timeout * 1000).to_i)
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
