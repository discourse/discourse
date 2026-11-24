# frozen_string_literal: true
class NativeBrowserPage
  attr_reader :target, :session, :context_id, :callbacks, :execution_contexts, :default_contexts
  attr_accessor :viewport,
                :clock,
                :routes,
                :network_listener_enabled,
                :pending_requests,
                :last_network_activity,
                :input_navigation_pending,
                :main_frame_id

  def initialize(target:, session:, viewport:, context_id: nil)
    @target = target
    @session = session
    @context_id = context_id
    @viewport = viewport
    @callbacks = Hash.new { |hash, key| hash[key] = [] }
    @execution_contexts = Set.new
    @default_contexts = {}
  end

  def emit(event, value)
    callbacks[event].each do |callback|
      callback.call(value)
    rescue StandardError => error
      @callback_errors ||= Queue.new
      @callback_errors << error if @callback_errors.empty?
    end
  end

  def raise_callback_error!
    error = @callback_errors&.pop(timeout: 0)
    raise error if error
  end
end
